/*
Jonathan Law
10/17/20
Project 1 simplebot - ECE540 Fall 20
*/
#define SEGMENT_CTL 0x80001038
#define SEGMENT_VAL 0x8000103c

// GPIO {16'bSW,16'bLED}
#define GPIO_SWs    0x80001400
#define GPIO_LEDs   0x80001404
#define GPIO_INOUT  0x80001408

// push button location {u,l,r,d}
#define PUSH_BUTTON 0x80001500
#define PBTN_S  0b0000
#define PBTN_LR 0b1000
#define PBTN_LF 0b0100
#define PBTN_RF 0b0010
#define PBTN_RR 0b0001
#define PBTN_R2 0b0101
#define PBTN_L2 0b1010
#define PBTN_F  0b0110
#define PBTN_R  0b1001

// motion (0=a,6=g)
#define MOTION_MAX 5
#define MOT_F 0
#define MOT_R 3
#define MOT_S 6
// compass
#define COMPASS_MAX 359
// time delay
//#define DELAY 0x100000
#define DELAY 100000

.global _start
_start:                         # init
        // control 7segment
        li t3, 0xf0             # 7segment oe_n
        li t4, SEGMENT_CTL     # 7segment control address
        sw t3, 0(t4)         # 0 = enable
        // control gpio
        li t3, 0xffff           # output enable mask, LED lower 16'b
        li t4, GPIO_INOUT       # GPIO address
        sw t3, 0(t4)             # enable GPIO

        // DELAY
        li t0, DELAY            # delay max
        li t2, 0                # delay count

        // 7segment display value
        //li t1, 0                # counter = 0
        li t4, SEGMENT_VAL     # 7segment value address
        li s11, 0               # decimal point indicator

        li a0, GPIO_LEDs        # output LED
//        li a1, GPIO_SWs         # input SW
        li a2, PUSH_BUTTON      # input push button
        li a4, MOT_S            # motion value
        li a5, 0                # compass value
        li a6, MOTION_MAX       # motion max
        li a7, COMPASS_MAX      # compass max
// init done
// main program loop
output:
        // output it
        sw t6, 0(a0)            # output to leds
        sw t5, 0(t4)           # output all 7seg

delay:                          # delay loop
        // full speed loop
        //lw t5, 0(a1)            # read switches
        //srl t6, t6, 16          # overlay switch to led pattern
        
        addi t2, t2, 1          # timer++
        bne t0, t2, delay       # timer loop
        // delay done
        and t2, zero, zero      # timer reset

poll_input:
        // push button, read and process
        lw t6, 0(a2)            # read push buttons

        // speed x2
        li t0, DELAY            # delay reset
        li t3, PBTN_R2          # PBTN left, down
        beq t3, t6, speed_fast
        li t3, PBTN_L2          # PBTN right, up
        beq t3, t6, speed_fast
        j direction

speed_fast:
        srl t0, t0, 1           # delay /2

direction:
        // right
        li t3, PBTN_LF          # PBTN left
        beq t3, t6, right       
        li t3, PBTN_RR          # PBTN down
        beq t3, t6, right       
        li t3, PBTN_R2          # PBTN left, down
        beq t3, t6, right       
        // left
        li t3, PBTN_RF          # PBTN right
        beq t3, t6, left
        li t3, PBTN_LR          # PBTN up
        beq t3, t6, left
        li t3, PBTN_L2          # PBTN right, up
        beq t3, t6, left
        // straight
        li t3, PBTN_F           # PBTN left, right
        beq t3, t6, forward
        li t3, PBTN_R           # PBTN up, down
        beq t3, t6, reverse
        // all other invalid push button states will go to stop
        j stop
//        li t3, PBTN_S           # PBTN none
//        beq t3, t6, stop
        
right:
        // right
        addi a4, a4, 1          # motion rotate
        bge a6, a4, right_compass       # rollover?
        li a4, 0                # 359 to 0
right_compass:
        addi a5, a5, 1          # compass rotate
        bge a7, a5, result      # rollover?
        li a5, 0                # segF to segA
        j result
left:
        // left
        addi a4, a4, -1         # motion rotate
        bge a4, zero, left_compass      # rollunder?
        li a4, MOTION_MAX       # 0 to 359
left_compass:
        addi a5, a5, -1         # compass rotate
        bge a5, zero, result    # rollunder?
        li a5, COMPASS_MAX      # segA to segF
        j result

forward:
        // forward
        li a4, MOT_F    # motion forward
        j result
reverse:
        // reverse
        li a4, MOT_R    # motion reverse
        j result
stop:
        // stop
        li a4, MOT_S    # motion stop

result:
        // merge values to result for output
        // result format {3'b[seg1],1'b[dp],12'b[compass]}
        sll t5, a4, 0           # motion value

        xor s11, s11, 1         # decimal point blink
        sll t5, t5, 1           # make room for decimal point
        add t5, t5, s11         # add decimal point to result

        sll t5, t5, 12          # make room for compass value
        add t5, t5, a5          # add compass to result

        j output
