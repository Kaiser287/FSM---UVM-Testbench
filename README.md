# Báo cáo Dự án: UVM Testbench kiểm chứng FSM phát hiện chuỗi "101"

> **Hồ sơ thực tập – Design Verification với phương pháp UVM**

## Mục lục

1. Giới thiệu & Mục tiêu
2. Mô tả DUT - FSM phát hiện chuỗi "101"
3. Kiến trúc UVM Testbench
4. Mô tả chi tiết các thành phần
5. Mô hình độ phủ (Functional Coverage)
6. Danh sách Testcase
7. Hướng dẫn biên dịch, mô phỏng & xác thực
8. Kết quả kiểm thử dự kiến
9. Cấu trúc thư mục dự án

---

## 1. Giới thiệu & Mục tiêu

Dự án xây dựng một **môi trường kiểm chứng UVM (Universal Verification Methodology)** hoàn chỉnh, tái sử dụng được, để kiểm chứng một **máy trạng thái hữu hạn (FSM)**. DUT được chọn là **bộ phát hiện chuỗi bit "101" có chồng lấp (overlapping sequence detector)** theo mô hình **Moore**.

Mục tiêu kiểm chứng:

- Xác minh FSM đi qua **đầy đủ 4 trạng thái** và **tất cả các chuyển trạng thái hợp lệ**.
- Xác minh ngõ ra `detected` được kích đúng khi và chỉ khi nhận được chuỗi "101".
- Xác minh hành vi **chồng lấp** (ví dụ "10101" cho 2 lần phát hiện).
- Đạt **độ phủ chức năng (functional coverage) 100%** cho trạng thái, chuyển trạng thái và cross.
- Tự động hóa việc so sánh kết quả bằng **mô hình tham chiếu trong scoreboard**.

## 2. Mô tả DUT - FSM phát hiện chuỗi "101"

FSM dùng mã hóa 2-bit với 4 trạng thái:

| Trạng thái | Mã | Ý nghĩa |
|---|---|---|
| `IDLE` | `00` | Chưa khớp ký tự nào |
| `S1`   | `01` | Đã nhận "1" |
| `S10`  | `10` | Đã nhận "10" |
| `S101` | `11` | Đã nhận "101" → **phát hiện** |

Bảng chuyển trạng thái (cho phép chồng lấp):

| Trạng thái hiện tại | din=0 | din=1 |
|---|---|---|
| `IDLE` | `IDLE` | `S1` |
| `S1`   | `S10`  | `S1` |
| `S10`  | `IDLE` | `S101` |
| `S101` | `S10`  | `S1` |

Ngõ ra Moore: `detected = (state == S101)`. Sơ đồ trạng thái được trình bày trong file `fsm_state_diagram.mmd`.

## 3. Kiến trúc UVM Testbench

```
                         fsm_tb_top (module)
        ┌────────────────────────────────────────────────┐
        │   clk/rst gen     fsm_if (interface)     DUT    │
        │                        │                        │
        │              uvm_config_db (vif)                │
        └────────────────────────┼───────────────────────┘
                                  │
                         ┌────────▼────────┐
                         │   fsm_env       │
                         │  ┌───────────┐  │
        sequence ───────►│  │ fsm_agent │  │
                         │  │  sqr→drv  │──┼──► din
                         │  │    mon    │◄─┼─── state_o/detected
                         │  └─────┬─────┘  │
                         │     ap │ (analysis port)
                         │   ┌────┴─────┐  │
                         │   ▼          ▼  │
                         │ scoreboard  coverage │
                         └──────────────────────┘
```

Luồng dữ liệu: **sequence** sinh các `fsm_item` (bit din) → **driver** lái lên interface → DUT xử lý → **monitor** quan sát `din/state_o/detected` và phát qua **analysis port** tới **scoreboard** (so sánh với mô hình tham chiếu) và **coverage** (thu thập độ phủ).

## 4. Mô tả chi tiết các thành phần

**`fsm_item`** — transaction chứa `din` (rand, do sequence điều khiển) và các trường quan sát `detected`, `state_o` (do monitor điền).

**`fsm_driver`** — lấy item từ sequencer, lái `din` lên `drv_cb` mỗi chu kỳ clock theo giao thức pipelined đơn giản.

**`fsm_monitor`** — lấy mẫu `din/state_o/detected` qua `mon_cb` ở mỗi cạnh lên clock (chỉ sau khi reset đã nhả), đóng gói thành `fsm_item` và phát qua `uvm_analysis_port`.

**`fsm_scoreboard`** — chứa một **mô hình tham chiếu FSM độc lập** (hàm `next_state`). Mỗi transaction nhận được, scoreboard so sánh trạng thái DUT với trạng thái mô hình, đồng thời kiểm tra ngõ ra Moore `detected == (state==S101)`. Thống kê PASS/FAIL được in trong `report_phase`.

**`fsm_coverage`** — `uvm_subscriber` chứa covergroup (xem mục 5).

**`fsm_agent` / `fsm_env`** — đóng gói sequencer+driver+monitor; env đấu nối analysis port của monitor tới **cả** scoreboard và coverage.
## 5. Mô hình độ phủ (Functional Coverage)

Covergroup `cg` trong `fsm_coverage` gồm:

- **`cp_state`** — 4 bins phủ đủ 4 trạng thái (`IDLE`, `S1`, `S10`, `S101`).
- **`cp_din`** — 2 bins (`0`, `1`) đảm bảo cả hai giá trị đầu vào được áp.
- **`cp_detect`** — 2 bins (`no`, `yes`) đảm bảo có lần phát hiện và không phát hiện.
- **`cp_trans`** — 8 transition bins phủ **toàn bộ chuyển trạng thái hợp lệ** của FSM (ví dụ `S10 => S101`, `S101 => S1` cho chồng lấp).
- **`cx_state_din`** — cross giữa trạng thái và đầu vào, đảm bảo mỗi trạng thái được kích bởi cả `0` và `1`.

Độ phủ được in trong `report_phase` (state / transition / tổng).

## 6. Danh sách Testcase

| Test | Mục đích | Loại |
|---|---|---|
| `fsm_pattern_test` | Phát chuỗi mẫu ép phát hiện "101" | Directed (chức năng) |
| `fsm_random_test` | 500 bit ngẫu nhiên dồn coverage | Constrained-random |
| `fsm_overlap_test` | Chuỗi "10101..." kiểm tra chồng lấp | Directed |
| `fsm_zeros_test` | Toàn 0 — trường hợp biên, không phát hiện | Corner case |
| `fsm_regression_test` | Chạy lần lượt nhiều sequence → coverage tối đa | Regression |

## 7. Hướng dẫn biên dịch, mô phỏng & xác thực

Thứ tự biên dịch nằm trong `fsm_run.f`. Ví dụ với Synopsys VCS:

```bash
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -cm line+cond+fsm+tgl -f fsm_run.f -l comp.log
./simv +UVM_TESTNAME=fsm_regression_test +UVM_VERBOSITY=UVM_LOW -cm line+cond+fsm+tgl
urg -dir simv.vdb -report cov_report
```

Lệnh cho Questa và Xcelium được ghi chú đầy đủ trong `fsm_run.f`. Chọn test qua tham số `+UVM_TESTNAME=<tên_test>`.

**Cách phân tích log:**

- Tìm dòng `*** TEST PASSED ***` / `*** TEST FAILED ***` từ scoreboard.
- Kiểm tra `UVM_ERROR : 0` ở cuối báo cáo UVM.
- Xem mục `ĐỘ PHỦ (COVERAGE)` để xác nhận state/transition coverage đạt 100%.
- Mở `fsm_tb.vcd` bằng waveform viewer để debug khi có lỗi.

## 8. Kết quả kiểm thử dự kiến

Với `fsm_regression_test`, kết quả mong đợi:

- Scoreboard: `UVM_ERROR : 0`, `*** TEST PASSED ***`, số lần phát hiện "101" > 0.
- State coverage: **100%** (4/4 trạng thái).
- Transition coverage: **100%** (8/8 chuyển trạng thái).
- Cross `cx_state_din`: tiệm cận 100% sau test random.

Các phát hiện điển hình mà môi trường này bắt được: đặc tả trạng thái thiếu (ví dụ quên xử lý chồng lấp ở `S101`), ngõ ra `detected` sai pha, và chuyển trạng thái bất hợp lệ — tất cả đều được scoreboard báo `UVM_ERROR` ngay lập tức.

## 9. Cấu trúc thư mục dự án

```
fsm_uvm/
├── fsm_dut.sv             # DUT - FSM phát hiện "101" (Moore)
├── fsm_if.sv              # Interface + clocking blocks
├── fsm_seq_pkg.sv         # fsm_item + sequencer + sequences
├── fsm_env_pkg.sv         # driver, monitor, coverage, scoreboard, agent, env
├── fsm_test_pkg.sv        # base test + 5 testcase
├── fsm_tb_top.sv          # top module: clk/rst, DUT, run_test
├── fsm_run.f              # file list + lệnh mô phỏng
├── fsm_state_diagram.mmd  # sơ đồ trạng thái
└── BAO_CAO_FSM_UVM.md     # tài liệu báo cáo này
```

---

*Dự án minh họa phương pháp UVM toàn diện: phân tầng (sequence → driver → DUT → monitor → scoreboard/coverage), tách biệt stimulus và checking, tự động hóa kiểm tra bằng mô hình tham chiếu, và đo lường chất lượng kiểm thử bằng functional coverage.*
