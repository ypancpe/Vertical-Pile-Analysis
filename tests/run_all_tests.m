function run_all_tests()
%RUN_ALL_TESTS Run the navfac_general test suite. Errors if anything fails.
%
%   From MATLAB/Octave:   >> cd tests; run_all_tests
%   Headless (CI):        matlab -batch "cd('<pkg>/tests'); run_all_tests"
%                         octave --eval "cd('<pkg>/tests'); run_all_tests"

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    addpath(fileparts(here));
    try, warning('off', 'backtrace'); end %#ok<TRYNC>  % cleaner logs (MATLAB)

    tests = {@test_regression_P1, @test_validation, @test_allpile_benchmark};
    failed = 0;
    for i = 1:numel(tests)
        name = func2str(tests{i});
        fprintf('\n===== %s =====\n', name);
        try
            tests{i}();
        catch err
            failed = failed + 1;
            fprintf(2, '%s FAILED: %s\n', name, err.message);
        end
    end

    fprintf('\n%d/%d test file(s) passed.\n', numel(tests) - failed, numel(tests));
    if failed > 0
        error('navfac_general:testsFailed', '%d test file(s) failed.', failed);
    end
end
