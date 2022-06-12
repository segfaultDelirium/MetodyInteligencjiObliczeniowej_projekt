% % partial functions testing 
% 
% mySum = 15;
% myA = 3;
% myB = 2;
% 
% res0 = add(mySum, myA, myB);
% disp(res0);
% 
% myPartial = partial(@newSum, myA, myB);
% res1 = myPartial(mySum);
% disp(res0)
% 
% function newSum = add(sum, a, b)
%     newSum = (sum - a) / b;
% end
% 
% function fn = partial(fn_, varargin)
%     args = varargin;
%     fn = @(varargin) fn_(args{:}, varargin{:});
% end
% 


% function fn = partial(fn_, varargin)
%     args = varargin;
%     fn = @(varargin) fn_(args{:}, varargin{:});
% end

import functools.*

mySum = 15;
fgddgds = 3;
dfsf43myht5654B = 2;

res0 = add(mySum, fgddgds, dfsf43myht5654B);
disp("res without partial:")
disp(res0);

myPartial = partial(@add, fgddgds, dfsf43myht5654B);
res1 = myPartial(mySum);
disp("res with partial")
disp(res0)

function newSum = add(sum, a, b)
    newSum = (sum - a) / b;
end

