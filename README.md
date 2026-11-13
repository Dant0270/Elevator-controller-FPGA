# Thang máy STEP MAX10 với bộ nhớ và chế độ về tầng 1

Bản hiện tại ngày 06/11/2026 trong elevator_basic. Bản elevator_v2 và các backup là lịch sử, không được compile cùng dự án này.
Mở elevator.qpf, top elevator_top, thiết bị 10M02SCM153I7G, clock 12 MHz J5.

## Cách sử dụng

- KEY1 -> tầng 4; KEY2 -> tầng 3; KEY3 -> tầng 2; KEY4 -> tầng 1.
- Floor/target dùng trực tiếp các số 1..4. Một chặng giữa hai tầng mất 1 giây.
- LED 7 đoạn thứ nhất hiển thị tầng hiện tại; segment active-high, DP=0 tắt, DIG1=0 bật, DIG2=1 tắt.
- Pending có 4 bit để lưu yêu cầu khi đang chạy hoặc đang báo đến tầng. Khi rảnh, chọn tầng gần nhất, hòa ưu tiên tầng thấp. Hoàn thành đích hiện tại trước, chưa đón dọc đường.
- Khi tới đích trong hoạt động thường, LED1 sáng 250 ms rồi tắt 250 ms, lặp đúng 3 nhịp (1,5 giây) trước khi chọn chuyến kế tiếp. Gọi ngay tầng đang đứng được phục vụ tại chỗ, không nháy thêm.
- LED1 được gán N15. LED_ACTIVE_LOW mặc định 0; nếu LED đơn trên kit có cực tính ngược, đổi tham số này thành 1. Cực tính LED đơn chưa được xác nhận bằng ảnh; không suy từ LED 7 đoạn.
- Buzzer BEEPER tại GPIO14/R11 phát 3 tiếng cùng LED báo đến tầng và ngắt quãng liên tục trong chế độ khẩn cấp. Sóng kích mặc định 2 kHz, tắt ở mọi khoảng không báo.

## SW4 là emergency_n chứ không còn reset

SW4/H13 -> đồng bộ hai flip-flop -> controller.emergency_n.

- Mức 1: bình thường.
- Mức 0: khẩn cấp. Ưu tiên cao hơn gọi tầng, hoàn tất bước di chuyển và báo đến tầng. Hủy queue cũ, target=1; nếu đang ở tầng trên thì bắt đầu chu trình đi xuống tầng 1.
- Mỗi bước đi xuống vẫn đủ thời gian 1 giây. Tại cạnh bắt đầu khẩn cấp, không thực hiện thêm bước thường; counter chuyển động bắt đầu lại từ 0.
- Tại tầng 1 giữ nguyên vị trí, bỏ qua các nút gọi khi còn khẩn cấp. LED1 nháy liên tục 250/250 ms, không giới hạn 3 nhịp.
- Mức về 1: nếu đã ở tầng 1 thì trở lại IDLE, nhận yêu cầu mới. Nếu tắt giữa đường về thì vẫn hoàn thành về tầng 1 rồi mới trở lại bình thường; LED khẩn cấp tiếp tục báo trong phần hành trình bắt buộc này.
- Khởi tạo/reset nội bộ chỉ xảy ra lúc FPGA bắt đầu chạy; không dùng SW4 để đặt lại vị trí tức thì.

Đây là chức năng đưa về tầng 1 trong mô hình học tập theo thời gian, không phải emergency stop dừng ngay hoặc bộ điều khiển thang máy cơ khí có cảm biến.

## Điều kiện để phát hiện hở dây

Quy ước active-low không tự bảo đảm phát hiện đứt dây. Nếu muốn hở dây cũng kích hoạt, trạng thái bình thường phải giữ đầu vào ở 1 qua tiếp điểm thường đóng và phải có điện trở kéo xuống ở phía đầu vào FPGA để khi tiếp điểm mở hoặc đường tín hiệu bị đứt thì về 0. Nút/công tắc trên board có sẵn điện trở kéo lên sẽ không tự có đặc tính này.

QSF đã tắt weak pull-up nội của emergency_n; việc đó không tạo điện trở kéo xuống. Nếu dùng mạch thường đóng bên ngoài, cần kiểm tra và đấu phần cứng phù hợp, không nối trực tiếp nguồn đối kháng với công tắc onboard. Không khẳng định phát hiện đứt dây của SW4 hiện có khi chưa kiểm tra mạch thực tế. Testbench chỉ kiểm tra các mức logic được cấp vào.

## Các trạng thái

- 0 IDLE: chờ/chọn đích.
- 1 UP: đi lên.
- 2 DOWN: đi xuống thông thường.
- 3 ARRIVED: đứng yên báo đúng 3 nhịp.
- 4 EMERGENCY_RETURN: bắt buộc đi về tầng 1.
- 5 EMERGENCY_WAIT: giữ tại tầng 1 đến khi emergency_n=1.

state_dbg hiện rộng 3 bit. Mọi thanh ghi vẫn chạy bằng clock 12 MHz. Counter đi tầng, counter báo 3 nhịp và counter nháy lỗi độc lập; LED khẩn cấp có ưu tiên hiển thị cao nhất.

## Các tệp

- rtl/button_input.sv: đồng bộ, chống dội 20 ms, xung một lần mỗi lần nhấn.
- rtl/elevator_controller.sv: FSM, bitmap yêu cầu, chọn đích, timer đi tầng, 3 nhịp báo và trở về tầng 1.
- rtl/sevenseg_decoder.sv: mã số 1..4 active-high.
- rtl/elevator_top.sv: khởi tạo nội bộ, đồng bộ emergency_n, ghép hiển thị và LED.
- constraints/elevator.sdc: clock 83.333 ns; I/O và đường bất đồng bộ còn cần review để sign-off timing đầy đủ.

## Chạy ModelSim

Từ Transcript:

```tcl
cd {E:/UET/Year 3/Digital design and Microprocessor/Lab/Final Project/elevator_basic/sim}
do run.do
```

Script trên kiểm tra tích hợp nút, hiển thị, ba nhịp và SW4. Để xem riêng trình tự khẩn cấp:

```tcl
do run_emergency.do
```

Tất cả kiểm thử: chạy `vsim -c -do test_all.do` từ sim; log tại sim/basic_tests.log. Tham số test được thu nhỏ để chạy nhanh, không biểu thị thời gian thật trên board.

## Kết quả kiểm tra

Ngày 06/11/2026, cả ba testbench đều PASS:

1. Controller thường: đúng ba xung/độ dài mỗi pha; đứng yên khi báo; lưu yêu cầu lúc đi và lúc nháy; nearest/tie; giá trị counter bằng 1.
2. Top: thứ tự KEY4..KEY1 theo số tầng, debounce/giữ nút, hiển thị active-high, adapter cực tính LED và đồng bộ SW4 active-low.
3. Emergency: tín hiệu mức 0 thắng bước đi lên và request trùng cạnh, queue xóa, về tầng 1, LED lặp liên tục, bỏ nút trong lỗi, hủy báo thường khi lỗi, nhả sớm vẫn về đủ và hoạt động lại sau khi nhả.

Quartus 20.1 Full Compilation ngày 06/11/2026 thành công: 0 lỗi, 9 cảnh báo; Fitter dùng 316 logic elements, 180 thanh ghi và 17 chân. File nạp mới: output_files/elevator.sof. Cảnh báo/constraint I/O cần được review trước khi coi là timing sign-off đầy đủ.

Chưa kiểm tra lại trên kit sau thay đổi này. Tài liệu Word/PDF cũ trong elevator_v2/docs mô tả phiên bản trước.

## Bổ sung mô phỏng buzzer ngày 06/11/2026

- rtl/buzzer_tone.sv tạo carrier; top dùng status_led làm enable trước adapter cực tính LED.
- sim/run.do đã thêm module buzzer và wave status_led, tone, beeper.
- sim/run_buzzer.do chạy test riêng carrier/enable/reset, giữ cửa sổ Wave sau $finish.
- sim/tb_elevator_top.sv dùng TONE_HALF_CYCLES=1 để thấy sóng trong khoảng báo ngắn, có kiểm tra báo đến tầng, khẩn cấp và im lặng ngoài khoảng báo; buzzer không phụ thuộc LED_ACTIVE_LOW.
- sim/test_all.do chạy 4 testbench. Lần chạy mới nhất PASS cả 4; compile ModelSim 0 lỗi/0 cảnh báo (vlib có thể báo thư viện đã tồn tại khi chạy lại).
- Đợt bổ sung này chỉ xác nhận simulation. File .sof từ lần Quartus trước chưa chứa buzzer cho đến khi biên dịch lại dự án.
- README.docx đã xuất trước lần bổ sung này nên chưa chứa phần buzzer mới.
