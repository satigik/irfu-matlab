%
% Function for either giving a warning, or an error depending on a setting (presumably a global setting).
%
%
% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created <=2016-10-28
%
function react_to_false_assertion(L, giveError, msg)
    % PROPOSAL: Abolish!
    
    if giveError
        error('BICAS:Assertion', msg)
    else
        LINE_FEED = char(10);
        L.log('warning', ['FALSE ASSERTION: ', msg, LINE_FEED])
    end
    
end
