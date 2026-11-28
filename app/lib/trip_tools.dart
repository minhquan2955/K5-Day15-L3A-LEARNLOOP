import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';
import 'travel_data.dart';

/// Bảng "Đổi kế hoạch" (bản tối thiểu): chọn thay đổi → ghép thành câu sửa → AI xếp lại, số liệu vẫn do công cụ tính.
/// Trả câu sửa, hoặc null nếu người dùng đóng bảng.
Future<String?> askReplan(
  BuildContext context,
  Itinerary itinerary,
  TravelState travel,
) {
  final names = <String>[
    for (final day in itinerary.days)
      if (day.details.isNotEmpty)
        for (final stop in day.details) stop.name
      else
        for (final stop in day.stops) stop.$2,
  ];
  final inPlan = names.map(searchable).toSet();
  final addable = [
    for (final place in travel.places)
      if (!inPlan.contains(searchable(place.name))) place.name,
  ];
  final drop = <String>{}, add = <String>{};
  final lodging = TextEditingController(), other = TextEditingController();
  String? start;
  var dayChange = 0;
  var leastTravel = false;

  String compose() => [
    if (drop.isNotEmpty) 'Bỏ ${drop.join(', ')}.',
    if (add.isNotEmpty) 'Thêm ${add.join(', ')}.',
    if (start != null) 'Ngày đầu bắt đầu từ $start.',
    if (dayChange != 0) 'Đổi thành ${itinerary.days.length + dayChange} ngày.',
    if (leastTravel) 'Xếp lại cho đỡ đi lòng vòng nhất.',
    if (lodging.text.trim().isNotEmpty) 'Mình ở ${lodging.text.trim()}.',
    if (other.text.trim().isNotEmpty) other.text.trim(),
  ].join(' ');

  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 5),
    child: Text(
      title,
      style: const TextStyle(
        color: ink,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    ),
  );

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: surface,
    constraints: const BoxConstraints(maxWidth: 460),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final text = compose();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Đổi kế hoạch', style: display(24, italic: true)),
                  const SizedBox(height: 4),
                  const Text(
                    'Chọn thay đổi rồi bấm Xếp lại. AI xếp lại lộ trình; giờ, '
                    'phút đi và tiền vé vẫn do công cụ tính.',
                    style: caption,
                  ),
                  section('Bỏ điểm'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in names)
                        FilterChip(
                          label: Text(name),
                          selected: drop.contains(name),
                          onSelected: (on) => setState(
                            () => on ? drop.add(name) : drop.remove(name),
                          ),
                        ),
                    ],
                  ),
                  section('Thêm điểm'),
                  if (addable.isEmpty)
                    const Text(
                      'Chưa có danh sách điểm (bản chạy thử không gọi máy chủ) — '
                      'gõ tên điểm vào "Yêu cầu khác".',
                      style: caption,
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final name in addable)
                          FilterChip(
                            label: Text(name),
                            selected: add.contains(name),
                            onSelected: (on) => setState(
                              () => on ? add.add(name) : add.remove(name),
                            ),
                          ),
                      ],
                    ),
                  section('Giờ bắt đầu ngày đầu'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final time in const [
                        '07:30',
                        '09:00',
                        '13:00',
                        '16:30',
                      ])
                        ChoiceChip(
                          label: Text(time),
                          selected: start == time,
                          onSelected: (on) =>
                              setState(() => start = on ? time : null),
                        ),
                    ],
                  ),
                  section('Số ngày (hiện ${itinerary.days.length})'),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (itinerary.days.length > 1)
                        ChoiceChip(
                          label: const Text('Bớt 1 ngày'),
                          selected: dayChange == -1,
                          onSelected: (on) =>
                              setState(() => dayChange = on ? -1 : 0),
                        ),
                      if (itinerary.days.length < 3)
                        ChoiceChip(
                          label: const Text('Thêm 1 ngày'),
                          selected: dayChange == 1,
                          onSelected: (on) =>
                              setState(() => dayChange = on ? 1 : 0),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: leastTravel,
                    title: const Text('Xếp cho đỡ đi lòng vòng nhất'),
                    subtitle: const Text(
                      'Mỗi ngày một hướng tính từ chỗ ở',
                      style: caption,
                    ),
                    onChanged: (on) => setState(() => leastTravel = on),
                  ),
                  TextField(
                    controller: lodging,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Chỗ ở (tuỳ chọn)',
                      hintText: 'vd: 20 Hàng Bạc, gần Hồ Tây',
                    ),
                  ),
                  TextField(
                    controller: other,
                    onChanged: (_) => setState(() {}),
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'Yêu cầu khác (tuỳ chọn)',
                      hintText: 'vd: ngày 2 chỉ rảnh từ 14h',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (text.isNotEmpty) Text('Sẽ gửi: "$text"', style: caption),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: text.isEmpty
                        ? null
                        : () {
                            travel.sync.log('doi_ke_hoach', {
                              'bo': drop.length,
                              'them': add.length,
                              'gio': start != null,
                              'ngay': dayChange,
                              'it_di_lai': leastTravel,
                              'cho_o': lodging.text.trim().isNotEmpty,
                              'khac': other.text.trim().isNotEmpty,
                            });
                            Navigator.of(context).pop(text);
                          },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Xếp lại'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Mở chat với câu yêu cầu soạn sẵn (người dùng xem / sửa rồi tự gửi).
void openChatDraft(BuildContext context, String draft) =>
    context.push('/ai', extra: {'draft': draft});

/// Đổi kế hoạch cho một chuyến đã lưu (ngoài chat): dựng lại yêu cầu từ chuyến + thay đổi → mở chat soạn sẵn.
Future<void> replanSavedTrip(
  BuildContext context,
  Itinerary itinerary,
  TravelState travel,
) async {
  final change = await askReplan(context, itinerary, travel);
  if (change == null || !context.mounted) return;
  openChatDraft(context, '${requestFromItinerary(itinerary)} $change');
}
