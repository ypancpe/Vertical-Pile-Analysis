% pile_calc.m -- single-case driver for the navfac_general package.
%
% Pick one input file from /inputs (by function name, without .m) and run:
%   >> pile_calc
%
% Everything else (defaults, validation, capacity, settlement, console
% report, CSV export to /outputs) happens inside ng_run_case. To run many
% cases at once, use pile_calc_batch instead.
clc; clear;

% ---------------- SELECT INPUT FILE ----------------
input_func_name = 'input_example_timber';   % change this to switch cases
% input_func_name = 'input_template';

results = ng_run_case(input_func_name);
