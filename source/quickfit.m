% Quickfit - graphical interface for non-linear curve fitting
%
% quickfit starts the graphical interface
% quickfit(x,y) sets the independent (x) and dependent (y) data.
%     x and y must be vectors of equal length.
% quickfit(x,y,ystd) also sets the uncertainty intervals (error bars) on y.
function qf = quickfit(x,y,ystd)
    % If there are arguments, process initial data
    if nargin>=2
        % Check to see if this is valid x and y data
        if isnumeric(x) && isnumeric(y) && isvector(x) && isvector(y) && length(x)==length(y)
            % Make sure x and y are row vectors
            x = x(:)';
            y = y(:)';
            
            % If the argument passed to quickfit were simple variables, we
            % can capture their name (otherwise it will be an empty string)
            xname = inputname(1);
            yname = inputname(2);
            
            % Check to see if there is ystd data
            if nargin>=3
                if isnumeric(ystd) && (isempty(ystd) || (isvector(ystd) && length(ystd)==length(x)))
                    ystd = ystd(:)';
                    ystdname = inputname(3);
                else
                    % Invalid data
                    disp('Error: ystd must be a vector with the same length as x and y.');
                end
            else
                % No ystd data
                ystd = []; ystdname = '';
            end
        else
            disp('Error: x and y must be vectors of equal length');
            return;
        end
    else
        x = []; xname = '';
        y = []; yname = '';
        ystd = []; ystdname = '';
    end
    
    % Settings file
    settingsfile = fullfile(fileparts(mfilename('fullpath')),'quickfitsettings.mat');
    
    % Create quickfit instance
    qf0 = quickfit.Instance(settingsfile);
    
    % Set data
    if ~isempty(x)
        qf0.setData(x,y,ystd,xname,yname,ystdname);
    end
    
    % Return quickfit object only if the function was called with an output argument
    if nargout>0
        qf = qf0;
    end
end