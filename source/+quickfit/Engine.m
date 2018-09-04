
classdef Engine < handle
    properties
        quickfit %#ok<*PROP>
    end
    methods
        function obj = Engine(theInstance)
            obj.quickfit = theInstance;
        end 
        function delete(obj)           
            obj.quickfit = [];
        end
        
    end
    methods (Static)
        % Takes the user input in the Function tab and creates a function
        % object (settings object)
        % On error, displays message boxes to the user and returns []
        % The 'name' field is left empty.
        function ok = testFunction(f)
            ok = false;
            
            % Check inputs
            if (length(f.parameters) < 1)
                msgbox('Specify one or more parameters.');
                return;
            end
            
            tmpx = [1 2 3 4 5];
            tmpy = [1 2 3 4 5];
            tmpystd = [1 1 1 1 1];
            tmpi = 1:5;
            try
                linitials = quickfit.Engine.evalXY(tmpx,tmpy,tmpystd,tmpi, f.initials);
            catch e
                msgbox(['Error evaluating initials: ',e.message]);
                return;
            end

            if (length(linitials) ~= length(f.parameters))
                msgbox('Specify an initial value for each parameter.');
                return;
            end

            % Evaluate the function once to test for errors etc in the equation
            try
                tmpfun = quickfit.Engine.makeFitFunction(f);
                tmpy = tmpfun(linitials,tmpx);
                if (size(tmpy)~=size(tmpx)) 
                    msgbox('The equation must return a vector the same size as the input.');
                    return;
                end
            catch e
                msgbox(['Error evaluating equation: ',e.message]);
            end

            ok = true;
        end
        
        % Returns a function handle to the function structure fun, taking fixedparams
        % into account (for fixed parameters, the corresponding initials value is used).
        %
        % The returned function has signature y = f(x,p), with p an array with only non-fixed
        % parameters, x the input data vector and y the result for each x.
        %
        % initials and fixedparams are optional (and only used if both are present).
        %
        % Implementation: each named parameter is declared as a variable, and then
        % the user supplied equation is executed, so that it can use the
        % variables. The evaluation is done in evalFitFunction to limit the number
        % of other variables that happen to be in scope.
        %
        % Notes: There may be a nicer way to do this. The current limitation is that
        %  a parameter named 'pawgsdfaweg' or 'equationpawgsdfaweg' would break the function.
        function f = makeFitFunction(fun, initials, fixedparams, paramscale)   
            parameters = cellstr(fun.parameters);
            usefixedparams = exist('initials','var') && exist('fixedparams','var');

            s = [];
            j = 0;
            for i = 1:length(parameters); 
                if usefixedparams && fixedparams(i)
                    %s = [s, parameters{i} '=' num2str(initials(i),12) '; ']; %#ok<AGROW>
                    s = [s, parameters{i} '=iawgsdfaweg(' num2str(i) '); ']; %#ok<AGROW>
                else
                    j = j + 1;  
                    s = [s, parameters{i} '=pawgsdfaweg(' num2str(j) ')*sawgsdfaweg(' num2str(j) '); ']; %#ok<AGROW>
                end
            end
            s = [s, 'y = ',fun.equation,';'];

            if ~exist('paramscale','var'), paramscale=ones(1,j); end;

            % Use evalFitFunction to pass on the string to evaluate
            f = @(p,x)quickfit.Engine.evalFitFunction(p,initials,x,s,paramscale);
        end

        % Helper function for evaluating the fit function (see makeFitFunction)
        function y = evalFitFunction(pawgsdfaweg,iawgsdfaweg,x,equationpawgsdfaweg,sawgsdfaweg) %#ok<INUSD,STOUT,INUSL>
            eval(equationpawgsdfaweg);
        end
        
        % Evaluate something as function of 'x','y','ystd' and 'index'
        function i = evalXY(x,y,ystd,index, equationasldfkjaslfjsaldkfjsalkdfjalks) %#ok<INUSL>
            i = eval(equationasldfkjaslfjsaldkfjsalkdfjalks);
        end

        
        function sf = getDefaultFunction()
            sf = cfw.Settings;
            sf.addSetting('name','<Custom>','editclass','char');
            sf.addSetting('description','','editclass','char');
            sf.addSetting('parameters',{'a'  'b'});
            sf.addSetting('initials','[1 0]','editclass','char');
            sf.addSetting('equation', 'a*x + b','editclass','char');
        end
        
        function [a,available] = getDefaultAlgorithm()    
            % See if algorithms exist. This method is a bit cumbersome, but it also
            % catches the case where a toolbox is in principle installed, but
            % it's license cannot be checked out.
            
            % Test algorithms in order of preference
            available = {};
            try
                % Statistics toolbox
                lsqnonlin(@(x)x,0,-1,1,optimset('display','off'));
                available{end+1} = 'lsqnonlin';
            catch
            end
            % no point in supporting lsqcurvefit, because it is just an
            % interface to lsqnonlin (but doesn't support ystd)
%             try
%                 lsqcurvefit(@(p,x)p*x,1,1,1,0,2,optimset('display','off'));
%                 available{end+1} = 'lsqcurvefit';
%             catch
%             end
            try
                % Optimization toolbox
                nlinfit([1 2],[1 2],@(p,x)p*x,1);
                available{end+1} = 'nlinfit';
            catch
            end
            try
                % Optimization toolbox
                fmincon(@(x)x.^2,0,[],[],[],[],-1,1,[],optimset('display','off'));
                available{end+1} = 'fmincon';
            catch
            end
            try
                % Core matlab function
                fminsearch(@(x)x.^2,0,optimset('display','off'));
                available{end+1} = 'fminsearch';
            catch
            end 
            if isempty(available)
                a = '';
                disp('WARNING: None of the implemented fitting routines are available. Fitting will not be possible.');
            else
                a = available{1};
            end
        end
        
        % Turns lsqcurvefit exitflag output into a description.
        function s = getLsqcurvefitExitflag(e)
            switch e
                case 1
                    s = 'Function converged to a solution.';
                case 2
                    s = 'Change in x was less than the specified tolerance.';
                case 3
                    s = 'Change in the residual was less than the specified tolerance.';
                case 4
                    s = 'Magnitude of search direction smaller than the specified tolerance.';
                case 0
                    s = 'Stopped after reaching MaxIter or MaxFunEvals.';
                case -1
                    s = 'Output function terminated the algorithm.';
                case -2
                    s = 'The lower and upper bounds are inconsistent.';
                case -4
                    s = 'Optimization could not make further progress';
                otherwise
                    s = 'Unknown';
            end
        end
        
        function s = formatresults(p,conf,names,fixedparams,texmode)
            if nargin<5, texmode = false; end;
            if nargin<4 || isempty(fixedparams), fixedparams = false(size(p)); end
            if nargin<3 || isempty(names), names = arrayfun(@(x)['p',num2str(x)],1:length(p),'uniformoutput',false); end
            
            sigfigs = 3; % This could be an option
            s = [];
            for i = 1:length(p)
                if i>1, s = [s,sprintf('\n')]; end;
                
                % Find required resolution in powers of 10
                lc = floor(log10(abs(conf(i)))); if isinf(lc), lc = -4; end;
                ld = floor(log10(abs(p(i))));

                if p(i) == 0 || (ld > -2 && ld < 3)
                    % print without exponent
                    if fixedparams(i)
                        ndigits = max(sigfigs, sigfigs-ld);
                        if isinf(ndigits), ndigits = sigfigs; end;
                        fmt = sprintf('%%s = %%.%df (fixed)', ndigits);                        
                        s = [s, sprintf(fmt, names{i}, p(i))];
                    elseif isnan(conf(i))
                        ndigits = max(sigfigs, sigfigs-ld);
                        if isinf(ndigits), ndigits = sigfigs; end;
                        fmt = sprintf('%%s = %%.%df', ndigits);                        
                        s = [s, sprintf(fmt, names{i}, p(i))];
                    else
                        ndigits = max(sigfigs-1-lc,0);
                        if texmode
                            fmt = sprintf('%%s = %%.%df \\\\pm %%.%df', ndigits, ndigits);
                        else
                            fmt = sprintf('%%s = %%.%df +/- %%.%df', ndigits, ndigits);                        
                        end
                        s = [s, sprintf(fmt, names{i}, p(i), conf(i))];
                    end
                else
                    % print with exponent
                    b = ld;

                    pb = p(i)*10^(-b);
                    cb = conf(i)*10^(-b);

                    if fixedparams(i)
                        ndigits = max(sigfigs,0);
                        if texmode
                            fmt = sprintf('%%s = %%.%df \\\\times 10^{%%d} (fixed)', ndigits);
                        else
                            fmt = sprintf('%%s = %%.%dfe%%+03d (fixed)', ndigits, ndigits);                        
                        end
                        s = [s, sprintf(fmt, names{i}, pb, b)];
                    elseif isnan(conf(i))
                        ndigits = max(sigfigs,0);
                        if texmode
                            fmt = sprintf('%%s = %%.%df \\\\times 10^{%%d}', ndigits);
                        else
                            fmt = sprintf('%%s = %%.%dfe%%+03d', ndigits, ndigits);                        
                        end
                        s = [s, sprintf(fmt, names{i}, pb, b)];
                    else
                        ndigits = max(sigfigs-1+ld-lc,0);
                        if texmode
                            fmt = sprintf('%%s = (%%.%df \\\\pm %%.%df) \\\\times 10^{%%d}', ndigits, ndigits);
                        else
                            fmt = sprintf('%%s = (%%.%df +/- %%.%df)e%%+03d', ndigits, ndigits);                        
                        end
                        s = [s, sprintf(fmt, names{i}, pb, cb, b)];
                    end
                end
            end
        end
    end
end