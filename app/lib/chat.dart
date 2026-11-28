import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pages.dart' show BadgeText;
import 'theme.dart';
import 'travel_data.dart';
import 'trip_tools.dart';

const apiBase = String.fromEnvironment('API', defaultValue: 'mock');
const demoPrompt =
    'Hãy tạo cho tôi lịch trình du lịch Hà Nội 2 ngày 1 đêm, yêu thích văn hóa, ẩm thực và chụp ảnh đẹp.';
const demoReply =
    'Đã có lịch trình dành cho bạn! Mình đã lên kế hoạch 2 ngày 1 đêm ở Hà Nội, tập trung vào văn hóa, ẩm thực và các điểm chụp ảnh đẹp. Bạn xem chi tiết nhé! 🌿';
const suggestions = [
  (Icons.edit_outlined, 'Thay đổi số ngày'),
  (Icons.place_outlined, 'Thêm địa điểm'),
  (Icons.savings_outlined, 'Tối ưu chi phí'),
  (Icons.my_location, 'Gợi ý khác'),
];

class ChatMessage {
  const ChatMessage(
    this.text, {
    this.user = false,
    this.itinerary,
    this.id,
    this.image,
    this.raw,
  });
  final String text;

  /// Toàn bộ output của máy chủ (dùng cho "Xem chi tiết" và khi gửi yêu cầu sửa).
  final String? raw;
  final bool user;
  final Itinerary? itinerary;
  final String? id;
  final Uint8List? image;
}

abstract class ChatRepository {
  const ChatRepository();
  Future<ChatMessage> reply(
    String text, {
    required String id,
    required String accessCode,
    String? previousRequest,
    String? previousOutput,
  });
}

class MockChatRepository extends ChatRepository {
  const MockChatRepository();

  @override
  Future<ChatMessage> reply(
    String text, {
    required String id,
    required String accessCode,
    String? previousRequest,
    String? previousOutput,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    return ChatMessage(demoReply, itinerary: sampleItinerary, id: id);
  }
}

class ApiChatRepository extends ChatRepository {
  const ApiChatRepository(this.base);
  final String base;

  @override
  Future<ChatMessage> reply(
    String text, {
    required String id,
    required String accessCode,
    String? previousRequest,
    String? previousOutput,
  }) async {
    var request = text;
    if (previousRequest != null) {
      final prefix = '$previousRequest\nLộ trình trước:\n';
      final suffix = '\n\nSửa: $text';
      final available = 4000 - prefix.runes.length - suffix.runes.length;
      if (available < 0) {
        throw const FormatException(
          'Yêu cầu chỉnh sửa quá dài. Hãy rút gọn hoặc mở cuộc trò chuyện mới.',
        );
      }
      final priorOutput = String.fromCharCodes(
        (previousOutput ?? '').runes.take(available),
      );
      request = '$prefix$priorOutput$suffix';
    }
    final response = await http
        .post(
          Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}/api/plan'),
          headers: {
            'Content-Type': 'application/json',
            if (accessCode.isNotEmpty) 'X-Access-Code': accessCode,
          },
          body: jsonEncode({'text': request}),
        )
        .timeout(const Duration(seconds: 100));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || body is! Map) {
      final detail = body is Map ? body['detail'] : null;
      throw FormatException(
        detail is String
            ? detail
            : 'Máy chủ trả về lỗi ${response.statusCode}.',
      );
    }
    final output = body['output']?.toString() ?? '';
    final itinerary = itineraryFromJson(body['itinerary']);
    return ChatMessage(
      itinerary == null
          ? output
          : itinerary.feasible
          ? 'Đã có lộ trình cho bạn. Bấm "Chỉ đường" để mở Google Maps, '
                '"Xem chi tiết" để đọc toàn bộ lưu ý.'
          : 'Chưa xếp được trọn vẹn — xem phần lưu ý trong thẻ để biết nên bỏ điểm nào hoặc thêm ngày.',
      itinerary: itinerary,
      id: id,
      raw: output,
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.travel,
    this.firstMessage = '',
    this.draft = '',
    this.repository,
  });
  final TravelState travel;
  final String firstMessage;

  /// Câu soạn sẵn đặt vào ô nhập (không tự gửi) — từ "Đổi kế hoạch" của chuyến đã lưu, Explore.
  final String draft;
  final ChatRepository? repository;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final repo =
      widget.repository ??
      (apiBase == 'mock'
          ? const MockChatRepository()
          : const ApiChatRepository(apiBase));
  final compose = TextEditingController();
  final scroll = ScrollController();
  final messages = <ChatMessage>[];
  Uint8List? attachment;
  String? attachmentName, error, previousRequest, previousOutput;
  ChatMessage? failed;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final sync = widget.travel.sync;
    sync.log('mo_man_hinh', {'man': 'chat'});
    if (repo is ApiChatRepository && sync.enabled && sync.consent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) askConsent(context, widget.travel);
      });
    }
    if (widget.draft.isNotEmpty) {
      compose.text = widget.draft;
      messages.add(
        const ChatMessage(
          'Mình đã soạn sẵn yêu cầu bên dưới — xem lại, sửa nếu cần rồi bấm Gửi.',
        ),
      );
    } else if (widget.firstMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) send(widget.firstMessage);
      });
    } else if (repo is MockChatRepository) {
      messages.addAll(const [
        ChatMessage(demoPrompt, user: true),
        ChatMessage(demoReply, itinerary: sampleItinerary, id: 'demo-preview'),
      ]);
    } else {
      messages.add(
        const ChatMessage('Bạn muốn khám phá Hà Nội trong bao nhiêu ngày?'),
      );
    }
  }

  @override
  void dispose() {
    compose.dispose();
    scroll.dispose();
    super.dispose();
  }

  void latest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> send(String text, {bool retry = false}) async {
    final content = text.trim();
    if (loading || content.isEmpty) return;
    if (content.runes.length > 4000) {
      setState(() => error = 'Tin nhắn vượt quá 4.000 ký tự.');
      return;
    }
    final message = retry
        ? failed!
        : ChatMessage(content, user: true, image: attachment);
    setState(() {
      if (!retry) messages.add(message);
      attachment = null;
      attachmentName = null;
      error = null;
      failed = null;
      loading = true;
    });
    if (!retry) compose.clear();
    latest();
    final sync = widget.travel.sync;
    final started = DateTime.now();
    sync.log('gui_yeu_cau', {
      'so_ky_tu': content.runes.length,
      'la_sua': previousRequest != null,
    });
    try {
      final reply = await repo.reply(
        content,
        id: 'chat-${DateTime.now().microsecondsSinceEpoch}',
        accessCode: widget.travel.accessCode,
        previousRequest: previousRequest,
        previousOutput: previousOutput,
      );
      final plan = reply.itinerary;
      sync.log('nhan_lich', {
        'ok': plan != null,
        'so_ngay': plan?.days.length ?? 0,
        'so_diem': plan?.days.fold<int>(0, (n, d) => n + d.stops.length) ?? 0,
        'kha_thi': plan?.feasible ?? false,
        'ms': DateTime.now().difference(started).inMilliseconds,
        'co_thoi_tiet': plan?.days.any((d) => d.weather != null) ?? false,
      });
      if (!mounted) return;
      setState(() {
        messages.add(reply);
        previousRequest ??= content;
        previousOutput = reply.raw ?? reply.text;
      });
    } on Exception catch (exception) {
      sync.log('loi_yeu_cau', {
        'ma': exception is FormatException ? 'may_chu' : 'mang',
      });
      if (!mounted) return;
      setState(() {
        error = exception is FormatException
            ? exception.message
            : 'Không kết nối được với AI. Bạn có thể gửi lại.';
        failed = message;
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
        latest();
      }
    }
  }

  Future<void> pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        attachment = bytes;
        attachmentName = image.name;
      });
    } on Exception {
      if (mounted) {
        setState(() => error = 'Không mở được ảnh. Bạn có thể thử lại.');
      }
    }
  }

  Future<void> options() async {
    if (repo is! ApiChatRepository) {
      await sheet<void>(
        context,
        'Tùy chọn',
        body: const Text(
          'Đây là bản chạy thử (lịch mẫu, không gọi AI). Chạy kèm máy chủ '
          '(docker compose, cổng 8080) để AI xếp lịch thật.',
          style: caption,
        ),
      );
      return;
    }
    var accessCode = widget.travel.accessCode;
    await sheet<void>(
      context,
      'Mã truy cập',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: accessCode,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mã truy cập API'),
            onChanged: (value) => accessCode = value,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              widget.travel.accessCode = accessCode.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Paper(
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 87),
              child: Stack(
                children: [
                  const Positioned.fill(child: BannerArt()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 13, 10, 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RoundAction(
                          Icons.arrow_back,
                          'Quay lại',
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                        ),
                        const SizedBox(width: 7),
                        const ChatAvatar(false, size: 42),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Travel Planner', style: display(23)),
                              const SizedBox(height: 2),
                              const Text(
                                'Chat with AI to plan your perfect trip in Hanoi',
                                style: caption,
                              ),
                            ],
                          ),
                        ),
                        RoundAction(
                          Icons.more_vert,
                          'Tùy chọn',
                          onTap: options,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                children: [
                  for (final message in messages) ...[
                    ChatBubble(
                      text: message.text,
                      user: message.user,
                      image: message.image,
                    ),
                    if (message.itinerary != null && message.id != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(33, 0, 0, 11),
                        child: ItineraryCard(
                          itinerary: message.itinerary!,
                          id: message.id!,
                          travel: widget.travel,
                          detail: message.raw,
                          onReplan: loading ? null : send,
                        ),
                      ),
                  ],
                  if (loading)
                    const ChatBubble(text: '', user: false, typing: true),
                  if (error != null)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            error!,
                            style: const TextStyle(color: Color(0xffa53522)),
                          ),
                          if (failed != null)
                            TextButton(
                              onPressed: () => send(failed!.text, retry: true),
                              child: const Text('Gửi lại'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 45,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => Material(
                  color: surface,
                  shape: const StadiumBorder(),
                  child: Pill(
                    suggestions[index].$2,
                    icon: suggestions[index].$1,
                    compact: true,
                    onTap: loading ? null : () => send(suggestions[index].$2),
                  ),
                ),
              ),
            ),
            if (attachmentName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        attachment!,
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: brown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachmentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bỏ ảnh',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        attachment = null;
                        attachmentName = null;
                      }),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: line),
                  boxShadow: shadow,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RoundAction(
                        Icons.image_outlined,
                        'Chọn ảnh',
                        onTap: loading ? null : pickImage,
                      ),
                      Expanded(
                        child: Focus(
                          onKeyEvent: (_, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                !HardwareKeyboard.instance.isShiftPressed) {
                              if (!loading && compose.text.trim().isNotEmpty) {
                                send(compose.text);
                              }
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: compose,
                            minLines: 1,
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Nhắn tin cho AI...',
                              border: InputBorder.none,
                              hintStyle: caption,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: compose,
                        builder: (context, value, _) => RoundAction(
                          Icons.send_rounded,
                          'Gửi',
                          filled: true,
                          onTap: loading || value.text.trim().isEmpty
                              ? null
                              : () => send(value.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar(this.user, {super.key, this.size = 33});
  final bool user;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: brand),
    child: Icon(
      user ? Icons.person_outline : Icons.smart_toy_outlined,
      color: Colors.white,
      size: size * .55,
    ),
  );
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.user,
    this.typing = false,
    this.image,
  });
  final String text;
  final bool user, typing;
  final Uint8List? image;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final bubble = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * (user ? .77 : .82),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: user ? const Color(0xfff4dcb8) : surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(19),
                topRight: const Radius.circular(19),
                bottomLeft: Radius.circular(user ? 19 : 5),
                bottomRight: Radius.circular(user ? 5 : 19),
              ),
              boxShadow: user ? null : shadow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: typing
                  ? Semantics(
                      label: 'AI đang trả lời',
                      child: const TypingDots(),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (image != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                image!,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: brown,
                                ),
                              ),
                            ),
                          ),
                        SelectableText(
                          text,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
        return Row(
          mainAxisAlignment: user
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user) ...[const ChatAvatar(false), const SizedBox(width: 7)],
            bubble,
            if (user) ...[const SizedBox(width: 7), const ChatAvatar(true)],
          ],
        );
      },
    ),
  );
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  )..repeat();

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brown.withValues(
                alpha: (animation.value * 3).floor() == i ? 1 : .34,
              ),
            ),
          ),
      ],
    ),
  );
}

class ItineraryCard extends StatelessWidget {
  const ItineraryCard({
    super.key,
    required this.itinerary,
    required this.id,
    required this.travel,
    this.detail,
    this.onReplan,
  });
  final Itinerary itinerary;
  final String id;
  final TravelState travel;
  final String? detail;

  /// Nhận câu sửa từ bảng "Đổi kế hoạch" (chat: gửi như lượt sửa; chuyến đã lưu: mở chat soạn sẵn).
  final void Function(String change)? onReplan;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Art('lake.jpg', width: 98, height: 70, radius: 12),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itinerary.title, style: display(18)),
                  const SizedBox(height: 4),
                  Meta(Icons.calendar_month_outlined, itinerary.duration),
                  const Meta(Icons.place_outlined, 'Hà Nội'),
                  if (itinerary.tags.isNotEmpty)
                    Meta(Icons.people_outline, itinerary.tags),
                ],
              ),
            ),
          ],
        ),
        if (!itinerary.feasible)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: BadgeText(
              'Chưa xếp được trọn vẹn — xem lưu ý',
              background: Color(0xfff6d9cf),
              foreground: Color(0xffa53522),
            ),
          ),
        for (var i = 0; i < itinerary.days.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: itinerary.days[i].details.isEmpty
                ? DayPreview(index: i + 1, day: itinerary.days[i])
                : DayPlan(
                    index: i + 1,
                    day: itinerary.days[i],
                    tripId: id,
                    travel: travel,
                  ),
          ),
        if (itinerary.totalVnd != null) ...[
          const SizedBox(height: 8),
          Meta(
            Icons.payments_outlined,
            'Tổng vé ${vnd(itinerary.totalVnd!)}'
            '${itinerary.perPersonVnd == null ? '' : ' (${vnd(itinerary.perPersonVnd!)}/người)'}'
            '${itinerary.taxiVnd == null ? '' : ' · taxi ước tính ${vnd(itinerary.taxiVnd!)} (chỉ tham khảo)'}',
          ),
        ],
        if (itinerary.keyNotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          KeyNotes(notes: itinerary.keyNotes),
        ],
        if (itinerary.days.any((day) => day.weather != null))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => openLink(context, 'https://open-meteo.com/'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                foregroundColor: muted,
              ),
              child: const Text(
                'Weather data by Open-Meteo.com',
                style: TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        const SizedBox(height: 9),
        ListenableBuilder(
          listenable: travel,
          builder: (context, _) {
            final saved = travel.isSaved(id);
            return Row(
              children: [
                Expanded(
                  child: Pill(
                    'Xem chi tiết',
                    icon: Icons.description_outlined,
                    compact: true,
                    onTap: () {
                      travel.sync.log('xem_chi_tiet');
                      sheet<void>(
                        context,
                        itinerary.title,
                        body: detail == null && itinerary.notes.isEmpty
                            ? null
                            : ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * .6,
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    detail ??
                                        itinerary.notes
                                            .map((note) => '- $note')
                                            .join('\n'),
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Pill(
                    'Đổi kế hoạch',
                    icon: Icons.edit_calendar_outlined,
                    compact: true,
                    onTap: onReplan == null
                        ? null
                        : () async {
                            final change = await askReplan(
                              context,
                              itinerary,
                              travel,
                            );
                            if (change != null) onReplan!(change);
                          },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Pill(
                    saved ? 'Đã lưu' : 'Lưu trip',
                    icon: saved ? Icons.favorite : Icons.favorite_border,
                    compact: true,
                    onTap: () => travel.toggleTrip(id, itinerary),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class DayPreview extends StatelessWidget {
  const DayPreview({super.key, required this.index, required this.day});
  final int index;
  final ItineraryDay day;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BadgeText('Ngày $index', background: brown, foreground: Colors.white),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, name) in day.stops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 4),
                          child: Icon(
                            Icons.radio_button_unchecked,
                            size: 9,
                            color: brown,
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$label: ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(text: name),
                              ],
                            ),
                            style: caption.copyWith(fontSize: 11, color: ink),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Art(day.image, width: 77, height: 63, radius: 10),
        ],
      ),
    ],
  );
}

/// Mở link ngoài (Google Maps, Open-Meteo) ở tab / app mới.
Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Exception {
    ok = false;
  }
  if (!ok) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Không mở được liên kết.')),
    );
  }
}

/// Một ngày trong lịch do API trả: giờ đến, số phút, vé, lý do, nút chỉ đường.
class DayPlan extends StatelessWidget {
  const DayPlan({
    super.key,
    required this.index,
    required this.day,
    this.tripId,
    this.travel,
  });
  final int index;
  final ItineraryDay day;

  /// Có [tripId] + [travel] thì hiện nút check-in "Đã xong" cho từng điểm.
  final String? tripId;
  final TravelState? travel;

  static const _weekdays = [
    'thứ Hai',
    'thứ Ba',
    'thứ Tư',
    'thứ Năm',
    'thứ Sáu',
    'thứ Bảy',
    'Chủ nhật',
  ];

  String get title {
    final date = day.date;
    if (date == null) return 'Ngày $index';
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Ngày $index · ${_weekdays[date.weekday - 1]} '
        '${two(date.day)}/${two(date.month)}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          BadgeText(title, background: brown, foreground: Colors.white),
          if (day.weather != null)
            Meta(
              (day.weather!.rainChance ?? 0) >= 60
                  ? Icons.umbrella_outlined
                  : Icons.wb_cloudy_outlined,
              day.weather!.label,
            ),
        ],
      ),
      const SizedBox(height: 6),
      for (var k = 0; k < day.details.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tripId != null && travel != null)
                CheckInButton(
                  travel: travel!,
                  tripId: tripId!,
                  day: index,
                  order: k + 1,
                  stop: day.details[k],
                ),
              Container(
                margin: const EdgeInsets.only(top: 1, right: 7),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  day.details[k].arrive,
                  style: const TextStyle(
                    color: brown,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.details[k].name,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (day.details[k].facts.isNotEmpty)
                      Text(
                        day.details[k].facts,
                        style: caption.copyWith(fontSize: 11),
                      ),
                    if (day.details[k].reason.isNotEmpty)
                      Text(
                        day.details[k].reason,
                        style: caption.copyWith(
                          fontSize: 11,
                          color: ink,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              if (day.details[k].mapsUrl != null)
                IconButton(
                  tooltip: 'Chỉ đường đến ${day.details[k].name}',
                  onPressed: () {
                    travel?.sync.log('bam_chi_duong', {
                      'cap': 'diem',
                      'dia_diem_id': ?day.details[k].placeId,
                    });
                    openLink(context, day.details[k].mapsUrl!);
                  },
                  icon: const Icon(
                    Icons.directions_outlined,
                    color: brown,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < day.routeUrls.length; i++)
            Pill(
              day.routeUrls.length == 1
                  ? 'Chỉ đường cả ngày'
                  : 'Chỉ đường phần ${i + 1}',
              icon: Icons.map_outlined,
              compact: true,
              onTap: () {
                travel?.sync.log('bam_chi_duong', {'cap': 'ngay'});
                openLink(context, day.routeUrls[i]);
              },
            ),
        ],
      ),
    ],
  );
}

/// Lưu ý quan trọng hiện thẳng trên thẻ (tối đa 4); còn lại xem trong "Xem chi tiết".
class KeyNotes extends StatelessWidget {
  const KeyNotes({super.key, required this.notes, this.max = 4});
  final List<String> notes;
  final int max;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lưu ý',
            style: TextStyle(
              color: brown,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final note in notes.take(max))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    note.startsWith('KHÔNG XẾP') || note.startsWith('Không xếp')
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    size: 14,
                    color: brown,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: caption.copyWith(fontSize: 11, color: ink),
                    ),
                  ),
                ],
              ),
            ),
          if (notes.length > max)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${notes.length - max} lưu ý khác — bấm "Xem chi tiết"',
                style: caption.copyWith(fontSize: 11),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Nút check-in "Đã xong" cho một điểm (lưu lên máy chủ nếu chuyến đã lưu).
class CheckInButton extends StatelessWidget {
  const CheckInButton({
    super.key,
    required this.travel,
    required this.tripId,
    required this.day,
    required this.order,
    required this.stop,
  });
  final TravelState travel;
  final String tripId;
  final int day, order;
  final StopDetail stop;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: travel,
    builder: (context, _) {
      final done = travel.isDone(tripId, day, order);
      return IconButton(
        tooltip: done
            ? 'Bỏ đánh dấu đã xong ${stop.name}'
            : 'Đánh dấu đã xong ${stop.name}',
        onPressed: () =>
            travel.toggleDone(tripId, day, order, placeId: stop.placeId),
        icon: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? const Color(0xff5b7330) : brown,
          size: 20,
        ),
        visualDensity: VisualDensity.compact,
      );
    },
  );
}

/// Hỏi đồng ý thu thập cách dùng app (ẩn danh) — hiện một lần khi mở chat ở chế độ gọi máy chủ.
Future<void> askConsent(BuildContext context, TravelState travel) async {
  final yes = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Giúp cải thiện gợi ý?'),
      content: const Text(
        'Cho phép ghi lại cách bạn dùng app — bấm nút nào, lịch có được lưu, '
        'điểm nào đánh dấu "Đã xong" — để biết lộ trình nào đi được thật.\n\n'
        '• Ẩn danh: mã ngẫu nhiên theo máy, không tên, không email.\n'
        '• Không lưu nội dung câu hỏi, không lưu vị trí GPS.\n'
        '• Tắt hoặc xoá dữ liệu bất cứ lúc nào trong Profile.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Không, cảm ơn'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Đồng ý'),
        ),
      ],
    ),
  );
  await travel.sync.setConsent(yes ?? false);
  travel.changed();
}
