% ci_run.m - headless test runner. Writes everything to tests/ci_run.log
% (console capture of matlab.exe -batch is unreliable on Windows) and
% exits nonzero on failure:
%   matlab -wait -batch "run('<pkg>\tests\ci_run.m')"
here = fileparts(mfilename('fullpath'));
cd(here);
logp = fullfile(here, 'ci_run.log');
donep = fullfile(here, 'ci_done.txt');
if exist(logp, 'file'), delete(logp); end
if exist(donep, 'file'), delete(donep); end
diary(logp);
ok = true;
try
    run_all_tests();
catch err
    ok = false;
    disp(getReport(err));
end
diary off;
fid = fopen(donep, 'w');
if ok, fprintf(fid, 'PASS\n'); else, fprintf(fid, 'FAIL\n'); end
fclose(fid);
if ~ok
    exit(1);
end
