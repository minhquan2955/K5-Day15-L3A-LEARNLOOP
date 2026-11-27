# Khai báo dùng AI

README của nhóm có mục "Dùng AI vào việc gì" (2–3 dòng, bắt buộc). Ghi chi tiết vào bảng dưới đây.

> Luật của đề: dùng AI để làm bài thoải mái, nhưng **ai không giải thích được phần có tên mình thì phần đó nhận 0 điểm**. Khai thiếu không bị trừ; giấu mới bị.

| Việc | Công cụ AI | AI làm gì | Người kiểm/sửa gì | Ai phụ trách |
|---|---|---|---|---|
| Code bản chạy thử | Antigravity (coding agent) | Dựng khung 3 công cụ đọc `data/hanoi_poi.json` (`tools.py`) và khung workflow 5 bước (`agent.py`) | Kiểm công thức tính giờ, tiền vé, đọc lại toàn bộ code và chạy thử | Phạm Trường Chinh, Đỗ Duy Bộ |
| Prompt / thiết kế lời gọi mô hình | Antigravity (coding agent) | Gợi ý `SYSTEM` prompt nháp theo `spec.md` §4 | Chỉnh điều kiện hỏi lại / từ chối, tinh chỉnh khi nối model thật ở CP3 | Phạm Trường Chinh, Nguyễn Văn Ba |
| Đào data (viết script đếm, gợi ý nhãn) | Không dùng | — | — | — |
| Rà câu hỏi phỏng vấn / khảo sát | Antigravity (coding agent) | Chỉ rà câu dẫn dắt và gợi ý bộ câu hỏi hành vi | Nhóm tự chốt câu hỏi, tự thực hiện phỏng vấn và phát hành form | Nguyễn Minh Quân |
| Viết câu thử (benchmark) | Nhóm tự viết (AI rà format) | Rà chính tả CSV và khớp `spec.md` §5 | Nhóm tự thiết kế 14 câu thử và `metric_spec.yaml`, tự bổ sung câu từ người dùng ở CP3 | Nguyễn Văn Ba, Nguyễn Minh Quân |
| Sinh data `synthetic` (nếu có) | Không dùng AI sinh tự động | — | Nhóm tự dựng 14 điểm `data/hanoi_poi.json` bằng tay, kiểm tay 14/14 dòng | Nguyễn Minh Quân, Đỗ Duy Bộ |
| Chấm cột `pass` bằng LLM (nếu có) | Không dùng | — | Chấm bằng code kiểm trace + người chấm độc lập | Nguyễn Văn Ba, Phạm Trường Chinh |
| Slide, văn bản | Antigravity (coding agent) | Hỗ trợ tổng hợp bảng `eval/README.md` mục 1–4, `spec.md`, `canvas.md` từ file có sẵn | Nhóm kiểm lại từng số liệu, không bịa số phỏng vấn | Nguyễn Minh Quân |

**Không dùng AI để:** tạo người được phỏng vấn, trích dẫn, câu trả lời khảo sát; sửa kết quả các lượt đã chạy (`eval/run-*.csv`, `cost/simulate-*.csv`, `traces/`).
