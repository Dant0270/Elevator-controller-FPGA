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

