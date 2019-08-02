%
% Automatic test code for bicas.utils.parse_CLI_options.
%
function parse_CLI_options___ATEST


Ocm1 = containers.Map(...
        {'a', 'b', 'c'}, ...
        {...
            struct('optionHeaderRegexp', '-a', 'occurrenceRequirement', '0-1',   'nValues', 0), ...
            struct('optionHeaderRegexp', '-b', 'occurrenceRequirement', '1',     'nValues', 1), ...
            struct('optionHeaderRegexp', '-c', 'occurrenceRequirement', '0-inf', 'nValues', 2)...
        });

Ocm2 = containers.Map(...
        {'--', '=='}, ...
        {...
            struct('optionHeaderRegexp', '--.*', 'occurrenceRequirement', '0-1',   'nValues', 0), ...
            struct('optionHeaderRegexp', '==.*', 'occurrenceRequirement', '0-inf', 'nValues', 0) ...
        });
    
Ocm3 = containers.Map(...
        {'all', 'log', 'set'}, ...
        {...
            struct('optionHeaderRegexp', '--.*',    'occurrenceRequirement', '0-inf', 'nValues', 1, 'interprPriority', -1), ...
            struct('optionHeaderRegexp', '--log',   'occurrenceRequirement', '1',     'nValues', 1), ...
            struct('optionHeaderRegexp', '--set.*', 'occurrenceRequirement', '0-inf', 'nValues', 1) ...
        });
    
tl = {};
tl{end+1} = new_test(Ocm1, '-b 123',                  {'a', 'b', 'c'}, {{},         {{'-b', '123'}},   {}});
tl{end+1} = new_test(Ocm1, '-a -b 123',               {'a', 'b', 'c'}, {{{'-a'}},   {{'-b', '123'}},   {}});
tl{end+1} = new_test(Ocm1, '-a -b 123 -c 8 9',        {'a', 'b', 'c'}, {{{'-a'}},   {{'-b', '123'}},   {{'-c', '8', '9'}                  }});
tl{end+1} = new_test(Ocm1, '-c 6 7 -a -b 123 -c 8 9', {'a', 'b', 'c'}, {{{'-a'}},   {{'-b', '123'}},   {{'-c', '6', '7'}, {'-c', '8', '9'}}});
tl{end+1} = new_test(Ocm1, '-c 6 7 -b 123 -c 8 9',    {'a', 'b', 'c'}, {{},         {{'-b', '123'}},   {{'-c', '6', '7'}, {'-c', '8', '9'}}});

tl{end+1} = new_test(Ocm2, '--ASD',                        {'--', '=='}, {{{'--ASD'}}, {}});
tl{end+1} = new_test(Ocm2, '==ASD ==a --abc',              {'--', '=='}, {{{'--abc'}}, {{'==ASD'}, {'==a'}}});

tl{end+1} = new_test(Ocm3, '--input1 i1 --output1 o1 --log logfile',               {'all', 'log', 'set'}, {{{'--input1', 'i1'}, {'--output1', 'o1'}}, {{'--log', 'logfile'}}, {}});
tl{end+1} = new_test(Ocm3, '--input1 i1 --output1 o1 --log logfile --setDEBUG ON', {'all', 'log', 'set'}, {{{'--input1', 'i1'}, {'--output1', 'o1'}}, {{'--log', 'logfile'}}, {{'--setDEBUG', 'ON'}}});

EJ_library.atest.run_tests(tl)

end



function NewTest = new_test(OptionsConfigMap, inputStr, outputMapKeys, outputMapValues)

input     = {strsplit(inputStr), OptionsConfigMap};
expOutput = {containers.Map(outputMapKeys, outputMapValues)};

NewTest = EJ_library.atest.CompareFuncResult(@bicas.utils.parse_CLI_options, input, expOutput);
end