function inp = ng_apply_defaults(inp)
%NG_APPLY_DEFAULTS Merge user input over ng_defaults; warn on unknown fields.
%
%   inp = ng_apply_defaults(inp)
%
%   - inp.par  : user values override def.par; missing fields get defaults.
%   - inp.pile : optional fields (pile_type, water_table_ft, gamma_w) get
%                defaults; required fields are checked by ng_validate_input.
%   - inp.opts : user values override def.opts.
%   - inp.Q_applied : top-level applied compression load [lb]; defaulted to
%                NaN (=> applied-load settlement skipped) when absent.
%
%   Unknown fields in inp.par, inp.opts, or inp.pile raise a warning
%   (likely a typo - e.g. "piletype" or "water_table" would otherwise be
%   silently ignored and the default used) but are kept, so
%   forward-compatible extra fields do not break runs.

    def = ng_defaults();

    if ~isfield(inp, 'par'),  inp.par  = struct(); end
    if ~isfield(inp, 'opts'), inp.opts = struct(); end
    if ~isfield(inp, 'pile'), inp.pile = struct(); end
    if ~isfield(inp, 'case_name'), inp.case_name = 'unnamed_case'; end
    if ~isfield(inp, 'Q_applied') || isempty(inp.Q_applied), inp.Q_applied = NaN; end

    inp.par  = merge_warn(def.par,  inp.par,  'par');
    inp.opts = merge_warn(def.opts, inp.opts, 'opts');
    % pile: required + optional fields beyond the defaults are whitelisted
    inp.pile = merge_warn(def.pile, inp.pile, 'pile', ...
        {'shape', 'size_in', 'embedment_ft', 'L', 'E', 'SW', 'A', 'P'});
end

function out = merge_warn(defaults, user, name, extra_known)
    out = defaults;
    fn = fieldnames(user);
    known = fieldnames(defaults);
    if nargin >= 4, known = [known(:); extra_known(:)]; end
    for i = 1:numel(fn)
        if ~any(strcmp(fn{i}, known))
            warning('navfac_general:unknownField', ...
                'inp.%s.%s is not a recognized field (typo?). Keeping it anyway.', ...
                name, fn{i});
        end
        out.(fn{i}) = user.(fn{i});
    end
end
