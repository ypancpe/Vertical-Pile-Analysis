function ng_write_csv(s, path)
%NG_WRITE_CSV Write a struct array to CSV (one row per element). Octave-safe.
%
%   ng_write_csv(s, path)
%
%   s    : 1xN struct array; fields must be scalar numerics/logicals or
%          char row vectors (the dbg.layers / summary structs qualify)
%   path : output file path
%
%   Replaces writetable/struct2table (absent in Octave). Numerics print
%   with %.10g, logicals as 0/1, char fields are quoted with internal
%   quotes doubled per RFC 4180.

    fn = fieldnames(s);
    fid = fopen(path, 'w');
    if fid < 0
        error('navfac_general:cantWrite', 'Cannot open "%s" for writing.', path);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '%s\n', strjoin(fn', ','));
    for r = 1:numel(s)
        parts = cell(1, numel(fn));
        for c = 1:numel(fn)
            v = s(r).(fn{c});
            if ischar(v)
                parts{c} = ['"' strrep(v, '"', '""') '"'];
            elseif islogical(v) && isscalar(v)
                parts{c} = sprintf('%d', v);
            elseif isnumeric(v) && isscalar(v)
                parts{c} = sprintf('%.10g', v);
            elseif isempty(v)
                parts{c} = '';
            else
                error('navfac_general:badCsvField', ...
                    'Field "%s" (row %d) is not a scalar/char - cannot serialize to CSV.', ...
                    fn{c}, r);
            end
        end
        fprintf(fid, '%s\n', strjoin(parts, ','));
    end
end
