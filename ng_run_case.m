function results = ng_run_case(case_ref, overrides)
%NG_RUN_CASE Run one case: load -> default -> validate -> compute -> print -> CSV.
%
%   results = ng_run_case('input_myCase')      % input function in inputs/
%   results = ng_run_case(inp_struct)          % or pass the struct directly
%   results = ng_run_case(..., overrides)      % optional struct overriding
%                                              % inp.par/.opts/.pile fields
%                                              % (used by batch/tests, e.g.
%                                              % struct('opts',struct('verbose',false)))
%
%   results fields:
%     inp        : the fully-defaulted, validated input actually used
%     cap        : capacity struct from ng_capacity
%     settlement : Vesic settlement struct from ng_settlement_vesic
%     dbg        : debug log (per-layer records, tip, summary, parameters)
%     csv_layers, csv_summary : paths of written CSVs ('' if write_csv off)

    pkg_dir = fileparts(mfilename('fullpath'));

    % ---- resolve input ----
    if ischar(case_ref)
        input_dir = fullfile(pkg_dir, 'inputs');
        if exist(input_dir, 'dir'), addpath(input_dir); end
        if ~exist(case_ref, 'file') && ~exist([case_ref '.m'], 'file')
            error('navfac_general:noInput', ...
                'Input function "%s" not found (looked in %s and the path).', ...
                case_ref, input_dir);
        end
        inp = feval(case_ref);
        tag = case_ref;
    elseif isstruct(case_ref)
        inp = case_ref;
        if isfield(inp, 'case_name'), tag = inp.case_name; else, tag = 'struct_input'; end
    else
        error('navfac_general:badCaseRef', ...
            'case_ref must be an input-function name (char) or an input struct.');
    end

    % ---- apply caller overrides (par/opts/pile), then defaults, validate ----
    if nargin >= 2 && isstruct(overrides)
        sub = {'par', 'opts', 'pile'};
        for k = 1:numel(sub)
            if isfield(overrides, sub{k})
                if ~isfield(inp, sub{k}), inp.(sub{k}) = struct(); end
                fn = fieldnames(overrides.(sub{k}));
                for j = 1:numel(fn)
                    inp.(sub{k}).(fn{j}) = overrides.(sub{k}).(fn{j});
                end
            end
        end
    end
    inp = ng_apply_defaults(inp);
    inp = ng_validate_input(inp);

    % ---- compute ----
    [cap, dbg] = ng_capacity(inp.pile, inp.layers, inp.par);
    st = ng_settlement_vesic(inp.pile, inp.layers, inp.par, cap, inp.Q_applied);
    dbg.settlement = st;

    % ---- console output ----
    ng_print_results(inp, cap, st, dbg);

    % ---- CSV output ----
    csv_layers = '';  csv_summary = '';
    if inp.opts.write_csv
        if ~isempty(inp.opts.output_dir)
            out_dir = inp.opts.output_dir;
        else
            out_dir = fullfile(pkg_dir, 'outputs');
        end
        if ~exist(out_dir, 'dir'), mkdir(out_dir); end
        safe = regexprep(lower(tag), '[^a-z0-9_\-]', '_');

        csv_layers = fullfile(out_dir, sprintf('layer_results_%s.csv', safe));
        ng_write_csv(dbg.layers, csv_layers);

        csv_summary = fullfile(out_dir, sprintf('summary_%s.csv', safe));
        ng_write_csv(ng_summary_row(inp, cap, st), csv_summary);

        if inp.opts.verbose
            fprintf('\nLayer results written to: %s\n', csv_layers);
            fprintf('Summary written to:       %s\n', csv_summary);
        end
    end

    results = struct('inp', inp, 'cap', cap, 'settlement', st, 'dbg', dbg, ...
        'csv_layers', csv_layers, 'csv_summary', csv_summary);
end
