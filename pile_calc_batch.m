function all_results = pile_calc_batch(case_names)
%PILE_CALC_BATCH Run several input cases and tabulate the results.
%
%   pile_calc_batch                    % runs every inputs/input_*.m
%                                      % (except input_template)
%   pile_calc_batch({'input_a', ...})  % or an explicit list
%
%   Each case runs quietly (no per-case console dump) but still writes its
%   per-layer and summary CSVs to /outputs. A one-line-per-case comparison
%   table is printed at the end and stacked into outputs/batch_summary.csv.

    pkg_dir = fileparts(mfilename('fullpath'));
    input_dir = fullfile(pkg_dir, 'inputs');
    addpath(input_dir);

    if nargin < 1 || isempty(case_names)
        d = dir(fullfile(input_dir, 'input_*.m'));
        case_names = {};
        for i = 1:numel(d)
            name = regexprep(d(i).name, '\.m$', '');
            if ~strcmp(name, 'input_template')
                case_names{end+1} = name; %#ok<AGROW>
            end
        end
    end
    if isempty(case_names)
        error('navfac_general:noCases', 'No input cases found in %s.', input_dir);
    end

    quiet = struct('opts', struct('verbose', false, 'print_layers', false));
    n = numel(case_names);
    rows = [];
    all_results = cell(1, n);

    fprintf('Running %d case(s)...\n', n);
    for i = 1:n
        fprintf('  [%d/%d] %s\n', i, n, case_names{i});
        res = ng_run_case(case_names{i}, quiet);
        all_results{i} = res;
        row = ng_summary_row(res.inp, res.cap, res.settlement);
        if isempty(rows), rows = row; else, rows(end+1) = row; end %#ok<AGROW>
    end

    % ---- console comparison table ----
    fprintf('\n%-28s %6s %9s %9s %9s %9s %9s %9s %9s %9s\n', 'case', 'D(in)', 'embed(ft)', ...
        'Qs_dn(k)', 'Qtip(k)', 'Qdn_ult', 'Qdn_all', 'Qup_ult', 'Xmax(in)', 's_appl(in)');
    for i = 1:numel(rows)
        r = rows(i);
        fprintf('%-28s %6.1f %9.1f %9.2f %9.2f %9.2f %9.2f %9.2f %9.4f %9.4f\n', ...
            truncate(r.case_name, 28), r.size_in, r.embedment_ft, ...
            r.Qside_down_kips, r.Qtip_kips, r.Qdown_ult_kips, ...
            r.Qdown_allow_kips, r.Qup_ult_kips, r.Xmax_in, r.s_applied_in);
    end

    % ---- batch CSV ----
    out_dir = fullfile(pkg_dir, 'outputs');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    batch_csv = fullfile(out_dir, 'batch_summary.csv');
    ng_write_csv(rows, batch_csv);
    fprintf('\nBatch summary written to: %s\n', batch_csv);
end

function s = truncate(s, n)
    if numel(s) > n, s = s(1:n); end
end
