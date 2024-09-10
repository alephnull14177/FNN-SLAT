// Project: FNN-Filter
// Testbench: filter_tb.sv
//
// This file provides the HDL testbench for the `filter` SV design.
//
// There are 3 modes of testing:
//  - Impulse Response                     [MODE 0]
//  - Sine Wave (frequency response)       [MODE 1]
//  - Real Data in the Field               [MODE 2]
//
// To set the proper mode, use the proper number for the `MODE` parameter. Modes
// 1 and 2 support reading data from a csv file found at the filepath parameter
// `INPUT_SIGNAL`.

`timescale 1ns/10ps


module filter_tb;
    // Enable this flag to print additional information during simulation
    parameter integer DEBUG = 1;
    // Determine how to run the simulation
    parameter integer MODE = 0;
    // Enable this flag to write the internal untruncated (64-bit) result to the output file
    parameter integer EXPANDED_Y = 0;
    // Load data from a file (only works for MODE 1 and MODE 2)
    parameter string INPUT_SIGNAL = "C:/Users/akell/Documents/FNN/FNN-mark/sine_511a60f5000000sf.csv";

    // Determine which set of internal signals to write to debug (structural or behavioral).
    localparam IS_STRUCT_WIRE_NAMING = 1;

    // Bits used for the operations
    localparam WHOLE_BITS = 10;  // Edit this to match requirements
    localparam FRAC_BITS = 32;   // Edit this to match requirements

    localparam WIDTH = WHOLE_BITS + FRAC_BITS;

    // Coefficicient params, edit COEFF_WHOLE/FRACT to match # bits in coefficient
    //     COEFF_WHOLE.COEFF_FRACT
    //localparam COEFF_WHOLE = 1;  // Edit this to match requirements
    //localparam COEFF_FRACT = 31; // Edit this to match requirements

    //localparam COEFF_PREPAD = WHOLE_BITS - COEFF_WHOLE;
    //localparam COEFF_SUFPAD = FRAC_BITS - COEFF_FRACT;

    // Number of ticks for a enter clock period
    localparam integer CLOCK_PERIOD = 2;

    // Number of samples to be '0' after 1 cycle of an impulse value
    localparam integer NUM_ZERO_SAMPLES = 500_000;

    // Latencies, update for design latency
//    localparam integer PIPE_LATENCY = 4;  // # of cycles between first input and first valid output
//    localparam integer COEFF_LATENCY = 4; // # of cycles before coefficients are saved internally
//                                          //   LAT needs 4 FPGA clocks to calculate LAT coefficients
    localparam integer PIPE_LATENCY = 3;  // # of cycles between first input and first valid output
    localparam integer COEFF_LATENCY = 1; // # of cycles before coefficients are saved internally

    // Connections to the design-under-test's (DUT's) interface
    logic clk;
    logic reset;
    logic[9:0] x_adc;
    logic coefficients_ready, sample_ready;
    logic[9:0] y_n;
    logic valid_out;


    // Test bench variable, used to fill pipeline for `latency` clocks
    integer _pipe_fill = 1;
    integer _pipe_flsh = 1;

    // Instantiate the DUT
    filter_top #(
        //.WHOLE_BITS(WHOLE_BITS), 
        //.FRAC_BITS(FRAC_BITS)
    ) dut (
        .x_adc(x_adc),
        .clk(clk),
        .coefficients_ready(coefficients_ready),
        .sample_ready(sample_ready),
        .reset(reset),
        .y_n(y_n),
        .valid_out(valid_out)
    );


    // Constantly drive a clock with 50% duty cycle.
    always begin
        #(CLOCK_PERIOD/2) clk <= 0;
        #(CLOCK_PERIOD/2) clk <= 1;
    end


    /// Sends active-high reset signal to the filter design, waits 4
    /// cycles, and then drives the reset low again.
    task reset_filter();
    begin

        reset = 1'b1;
        #(CLOCK_PERIOD*4);
        reset = 1'b0;
    end
    endtask


    /// This task is a function for driving the inputs into the filter DUT as
    /// well as writing intermediate/output values during computation to files.
    task drive_and_monitor(
        input integer outfile,
        input integer dbgfile,
        input integer latency, // Time from input to first output
        input coeff_ready,
        input sampl_ready, // note: name cannot match existing signal name o.w. bug
        input [9:0] value
    );
    begin
            
        // assign inputs
        drive(coeff_ready, sampl_ready, value);
        sampl_ready = '0;

        // wait a clock cycle for processing
        #CLOCK_PERIOD;
        // Capture outputs in files
        if (_pipe_fill < latency) begin // Fill pipeline first and then measure
            $display("Filling pipe: %2d", _pipe_fill);
            _pipe_fill = _pipe_fill + 1;
        end else begin
            monitor(outfile, dbgfile);
        end
    end
    endtask

    /// This task is a low-level function for driving the inputs into the filter DUT
    task drive(
        input coeff_ready,
        input sampl_ready, // note: name cannot match existing signal name o.w. bug
        input [9:0] value
    );
    begin
        // assign IO port values
        x_adc = value;
        coefficients_ready = coeff_ready;
        sample_ready = sampl_ready;
    end
    endtask

    /// This task is a low-level function for monitoring the inputs into the filter DUT
    /// as well as writing intermediate/output values during computation to files.
    task monitor(
        input integer outfile,
        input integer dbgfile
    );
    begin
        // Save output value as csv line
        if(EXPANDED_Y == 0) begin
            $fwrite(outfile, "%0t,%d\n", $time, signed'(dut.dut.afinal));
        end else begin
            if(IS_STRUCT_WIRE_NAMING == 0) begin
                // $fwrite(outfile, "%0t,%d\n", $time, signed'(dut.y[0]));
            end else begin
                $fwrite(outfile, "%0t,%d\n", $time, signed'(dut.dut.y_n_o));
            end
        end

        if(DEBUG > 0) begin
            //$fwrite(dbgfile, "%0t\n", $time);
            //$fwrite(dbgfile, "yn: %b\n", dut.dut.afinal);
            //$fwrite(dbgfile, "xn: %b\n", {{WHOLE_BITS-10{x_adc[9]}},{dut.x_adc[9:0]},{FRAC_BITS{1'b0}}});
            $fwrite(dbgfile, "%b\n", dut.dut.afinal);
            if(IS_STRUCT_WIRE_NAMING == 0) begin
                // $fwrite(dbgfile, "x[0]: %b\nx[1]: %b\nx[2]: %b\n\n", dut.x[0], dut.x[1], dut.x[2]);
                // $fwrite(dbgfile, "y[0]: %b\ny[1]: %b\ny[2]: %b\n\n", dut.y[0], dut.y[1], dut.y[2]);
            end else begin
                //$fwrite(dbgfile, "x[n-1]: %b\nx[n-2]: %b\ny[n-1]: %b\ny[n-2]: %b\n\n", dut.x_1, dut.x_2, dut.y_1, dut.y_2);
                //$fwrite(dbgfile, "sum_b  : %b\nsum_b12: %b\nsum_ab : %b\nsum_a  : %b\n\n", dut.sum_b, dut.sum_b12, dut.sum_ab, dut.sum_a);
                //$fwrite(dbgfile, "x0b0: %b\nx1b1: %b\nx2b2: %b\ny1a1: %b\ny2a2: %b\n\n", dut.x0b0, dut.x1b1, dut.x2b2, dut.y1a1, dut.y2a2);

                // Look-ahead transformed signals {{{
                //$fwrite(dbgfile, "xb0: %b\nxb1: %b\nxb2: %b\nxb3: %b\nxb4: %b\nxb4_ii: %b\ny[n-3]: %b\ny[n-4]: %b\ny3a1: %b\ny4a2: %b\n\n", dut.xb0, dut.xb1, dut.xb2, dut.xb3, dut.xb4, dut.xb4_ii, dut.y_3, dut.y_4, dut.y3a1, dut.y4a2);
                //$fwrite(dbgfile, "sum_b    : %b\nsum_b1234: %b\nsum_b234 : %b\nsum_b34  : %b\nsum_a    : %b\nsum_ab   : %b\n\n", dut.sum_b, dut.sum_b1234, dut.sum_b234, dut.sum_b34, dut.sum_a, dut.sum_ab);
                //$fwrite(dbgfile, "b0: %b\nb1: %b\nb2: %b\nb3: %b\nb4: %b\na1: %b\na2: %b\n\n", dut.b0_lat, dut.b1_lat, dut.b2_lat, dut.b3_lat, dut.b4_lat, dut.a1_lat, dut.a2_lat);
                // }}}
            end
            //$fwrite(dbgfile, "________________________________________________\n");
        end
    end
    endtask

    /// This task helps monitor the final outputs from the filter DUT
    task flush_pipeline(
        input integer outfile,
        input integer dbgfile,
        input integer latency, // Time from input to first output
        input [9:0] value
    );
    begin
        // Flush pipeline if necessary
        // TODO: Make sure this is enough clocks to flush out important values
        // TODO: Define 'important'
        _pipe_flsh = _pipe_fill;
        while (_pipe_flsh > 1) begin
            _pipe_flsh = _pipe_flsh - 1;
            $display("Flushing pipe: %2d", _pipe_flsh);
            drive_and_monitor(outfile, dbgfile, PIPE_LATENCY, 1'b1, 1'b1, value);
        end
    end
    endtask


    /// This task reads from a waveform data file to drive the filter design
    /// and read its outputs.
    task send_signal(input string file);
    begin
        automatic integer infile = $fopen(file, "r");
        // open a new output file
        automatic integer outfile = $fopen({file, ".out"}, "w");
        automatic integer dbgfile = $fopen("intermediate.txt", "w");
        automatic integer ret;
        automatic integer ind;
        automatic logic[9:0] adc_data = 'b0;
        automatic logic coeff_ready;
        automatic logic sampl_ready;

        // verify the input file exists
        assert(infile != 0) else $fatal("Signal file does not exist!");

        // enable control bits
        coeff_ready = 1'b1;
        sampl_ready = 1'b1;

        while(1) begin
            // parse each line from signal CSV
            ret = $fscanf(infile, "%d,%d", ind, adc_data);
            if(ret != 2) begin
                break;
            end

            if(DEBUG > 0) begin
                $display("Time: %d", ind);
                $display("ADC Input: %b (%d)", adc_data, signed'(adc_data));
                $display();
            end

            // assign inputs and capture outputs in files
            drive_and_monitor(outfile, dbgfile, PIPE_LATENCY, coeff_ready, sampl_ready, adc_data);
        end

        // Flush pipeline if necessary
        flush_pipeline(outfile, dbgfile, PIPE_LATENCY, adc_data);

        // close files using file descriptors
        $fclose(infile);
        $fclose(outfile);
        $fclose(dbgfile);
    end
    endtask


    /// This task sends the maximum value of the filter's input for a single cycle
    /// and then 0's for `num_samples` of cycles afterward.
    task impulse_response(input integer num_samples);
    begin
        automatic integer outfile;
        automatic integer dbgfile;
        automatic logic coeff_ready;
        automatic logic sampl_ready;

        automatic logic[9:0] impulse;

        $display("Opening output file...");
        outfile = $fopen("impulse.csv.out", "w");
        dbgfile = $fopen("intermediate.txt", "w");
        $display("Running sim...");

       

        // enable control bits
        coeff_ready = 1'b1;
        sampl_ready = 1'b1;

        // send a high-signal
        impulse = {1'b0, {9{1'b1}}};
        drive_and_monitor(outfile, dbgfile, PIPE_LATENCY, coeff_ready, sampl_ready, impulse);

       
        // send zero-value signal for remaining cycles.
        impulse = {10{1'b0}};
        for (integer times = 0; times < num_samples; times = times+1) begin
            drive_and_monitor(outfile, dbgfile, PIPE_LATENCY, coeff_ready, sampl_ready, impulse);
        end

        // Flush pipeline if necessary
        flush_pipeline(outfile, dbgfile, PIPE_LATENCY, impulse);

        $fclose(outfile);
        $fclose(dbgfile);
    end
    endtask


    /// The higher-level entrypoint logic orchestrating the testbench.
    initial begin
                
        // enable coefficients for rest of simulation
        coefficients_ready = 1'b1;

        
        reset_filter();

        // Wait until coefficients are calculated
        #(CLOCK_PERIOD*COEFF_LATENCY); // LAT needs 4 FPGA clocks to calculate LAT coefficients
        

        if(MODE == 0) begin
            $display("Running impulse simulation...");
      
            impulse_response(NUM_ZERO_SAMPLES);

        end else if(MODE == 1) begin
            $display("Running sine simulation...");
            send_signal(INPUT_SIGNAL);

        end else if(MODE == 2) begin
            $display("Running real simulation...");
            send_signal(INPUT_SIGNAL);

        end else begin
            $fatal("Error: Unsupported simulation mode %d", MODE);
        end

        #30 $finish;
    end
endmodule
