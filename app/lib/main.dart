import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

// Dev: flutter run -d chrome --dart-define=API=http://localhost:8000
// Deploy: để trống → gọi cùng origin (FastAPI phục vụ bản build này).
const apiBase = String.fromEnvironment('API');

// Nhãn khớp `so_thich` trong data/hanoi_poi.json.
const interests = {
  'di_tich': 'Di tích', 'lich_su': 'Lịch sử', 'van_hoa': 'Văn hoá',
  'am_thuc': 'Ẩm thực', 'pho_co': 'Phố cổ', 'dao_pho': 'Dạo phố',
  'bao_tang': 'Bảo tàng', 'kien_truc': 'Kiến trúc', 'tam_linh': 'Tâm linh',
  'thien_nhien': 'Thiên nhiên', 'chup_anh': 'Chụp ảnh', 'mua_sam': 'Mua sắm',
  'buoi_toi': 'Buổi tối', 'trai_nghiem': 'Trải nghiệm', 'tre_em': 'Hợp trẻ em',
  'ngoai_thanh': 'Ngoại thành',
};

void main() => runApp(const MaterialApp(
      title: 'LEARNLOOP — Lộ trình Hà Nội',
      home: PlanPage(),
    ));

/// Ghép form thành một câu tiếng Việt cho answer(text) (Q10).
String composeRequest({
  required int days,
  required int adults,
  required int kids,
  required Set<String> picked,
  required String budget,
  required String note,
}) {
  final parts = <String>[
    'Lần đầu đi Hà Nội $days ngày, $adults người lớn${kids > 0 ? ' và $kids trẻ em' : ''}.',
    if (picked.isNotEmpty) 'Thích: ${picked.map((k) => interests[k]).join(', ')}.',
    if (budget.trim().isNotEmpty) 'Ngân sách vé khoảng ${budget.trim()} đồng.',
    if (note.trim().isNotEmpty) note.trim(),
  ];
  return parts.join(' ');
}

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  int days = 2, adults = 1, kids = 0;
  final picked = <String>{};
  final budget = TextEditingController();
  final note = TextEditingController();
  final edit = TextEditingController();
  final code = TextEditingController();

  bool loading = false;
  String? error;
  String lastRequest = '';
  Map<String, dynamic>? result;

  Future<void> send(String text) async {
    setState(() { loading = true; error = null; });
    try {
      final r = await http.post(
        Uri.parse('$apiBase/api/plan'),
        headers: {'Content-Type': 'application/json', 'X-Access-Code': code.text},
        body: jsonEncode({'text': text}),
      );
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode != 200) throw body['detail'] ?? 'Lỗi ${r.statusCode}';
      setState(() { lastRequest = text; result = body; });
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      setState(() => loading = false);
    }
  }

  void submit() => send(composeRequest(
      days: days, adults: adults, kids: kids, picked: picked,
      budget: budget.text, note: note.text));

  // Stateless (Q9): gửi lại yêu cầu gốc + lộ trình trước + yêu cầu sửa.
  void resubmit() {
    if (edit.text.trim().isEmpty || result == null) return;
    send('$lastRequest\n\nLộ trình trước:\n${result!['output']}\n\nSửa: ${edit.text.trim()}');
    edit.clear();
  }

  Widget counter(String label, int value, int min, int max, ValueChanged<int> on) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          IconButton(icon: const Icon(Icons.remove), tooltip: 'Bớt $label',
              onPressed: value > min ? () => setState(() => on(value - 1)) : null),
          Text('$value'),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Thêm $label',
              onPressed: value < max ? () => setState(() => on(value + 1)) : null),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lộ trình Hà Nội cho người lần đầu đến')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 16, children: [
              counter('Số ngày', days, 1, 3, (v) => days = v),
              counter('Người lớn', adults, 1, 5, (v) => adults = v),
              counter('Trẻ em', kids, 0, 5, (v) => kids = v),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in interests.entries)
                FilterChip(
                  label: Text(e.value),
                  selected: picked.contains(e.key),
                  onSelected: (s) => setState(() => s ? picked.add(e.key) : picked.remove(e.key)),
                ),
            ]),
            TextField(controller: budget, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ngân sách vé (đồng, không bắt buộc)')),
            TextField(controller: note, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Ghi chú thêm (vd: muốn vào lăng Bác, không thích đi bộ nhiều)')),
            TextField(controller: code, obscureText: true,
                decoration: const InputDecoration(labelText: 'Mã truy cập')),
            const SizedBox(height: 12),
            FilledButton(onPressed: loading ? null : submit,
                child: Text(loading ? 'Đang xếp lộ trình…' : 'Xếp lộ trình')),
            if (error != null)
              Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red))),
            if (result != null) ...[
              const Divider(height: 32),
              ResultView(result: result!),
              TextField(controller: edit,
                  decoration: const InputDecoration(labelText: 'Sửa lộ trình (vd: bỏ chùa Hương, thêm Hồ Gươm)')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: loading ? null : resubmit, child: const Text('Xếp lại')),
            ],
          ]),
        ),
      ),
    );
  }
}

class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final it = result['itinerary'];
    final tokens = Text('Token: ${result['tokens']}', style: const TextStyle(color: Colors.grey));
    // Fallback (Q5): chưa có itinerary → hiện nguyên output.
    if (it is! Map) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [SelectableText('${result['output']}'), tokens]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (it['feasible'] == false)
        const Text('Không xếp được hết — xem gợi ý bên dưới.',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      for (final d in (it['days'] as List? ?? []))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ngày ${d['day']}', style: Theme.of(context).textTheme.titleMedium),
              for (final s in (d['stops'] as List? ?? []))
                ListTile(
                  leading: Text('${s['arrive']}'),
                  title: Text('${s['name']}'),
                  subtitle: Text('${s['reason']}\n'
                      'Đi ${s['travel_min_from_prev']} phút · tham quan ${s['visit_min']} phút · vé ${s['ticket_vnd']}đ'),
                ),
            ]),
          ),
        ),
      Text('Tổng vé: ${it['total_vnd']}đ · mỗi người: ${it['per_person_vnd']}đ'
          '${it['taxi_vnd'] != null ? ' · taxi ước tính: ${it['taxi_vnd']}đ' : ''}'),
      const SizedBox(height: 8),
      const Text('Lưu ý', style: TextStyle(fontWeight: FontWeight.bold)),
      for (final n in (it['notes'] as List? ?? [])) Text('• $n'),
      tokens,
    ]);
  }
}
