% Main class for Quickfit
classdef Instance < handle
    properties
        settings
        ui
        availableAlgorithms = {};
    end
    methods
        function obj = Instance(varargin)
            % Load settings first, because UI needs it to initialize
            % TODO: parse input arguments (x,y,[yerr],[fitfunction])
            if nargin>0
                obj.settings = obj.initializeSettings(varargin{1});
            else
                obj.settings = obj.initializeSettings();
            end
            obj.ui = quickfit.UI(obj);
        end 
        function delete(obj)
            if ~isempty(obj.ui), delete(obj.ui); end;
            if ~isempty(obj.settings), delete(obj.settings); end
        end
        

        function beforeClose(obj)
            % Save settings if possible
             if ~isempty(obj.settings.settingsFile)
                 tosave.info = struct('type','QuickfitSettings','version',1);
                 tosave.settings = obj.settings.getStructData(); %#ok<STRNU>
                 save(obj.settings.settingsFile,'-struct','tosave');
             end
            delete(obj);
        end
        
        
        function dataApply(obj, ignoreinput)
            if nargin<2, ignoreinput = false; end;
            
            % Reset all traces
            obj.clearTraces();
            
            data = obj.settings.session.data;
            tdata = struct('x',data.x,'y',data.y,'ystd',data.ystd);
            
            % Evaluate user input.
            if ~ignoreinput
                % x
                if (~strcmp('<Data>',data.xname))
                    try
                        tdata.x = double(evalin('base',data.xname));
                    catch me
                        msgbox(['Error evaluating x data: ',me.message]);
                        return;
                    end
                end

                % y
                if (~strcmp('<Data>',data.yname))
                    try
                        tdata.y = double(evalin('base',data.yname));
                    catch me
                        msgbox(['Error evaluating y data: ',me.message]);
                        return;
                    end
                end

                % std(y)
                if (~strcmp('<Data>',data.ystdname))
                    tdata.ystd = [];
                    if ~isempty(data.ystdname)
                        try
                            tdata.ystd = double(evalin('base',data.ystdname));
                        catch me
                            msgbox(['Error evaluating std(y) data: ',me.message]);
                            return;
                        end
                    end
                end
            end

            % Check if this is valid data
            if ~(isnumeric(tdata.x) && isnumeric(tdata.y) && isnumeric(tdata.ystd))
                msgbox('Error: x, y and std(y) must be numeric.');
                return;
            end
            if ~(isvector(tdata.x) && isvector(tdata.y) && length(tdata.x)==length(tdata.y))
                msgbox('Error: x, y must be vectors of the same length.');
                return;
            end
            if ~(isnumeric(tdata.ystd) && (isempty(tdata.ystd) || (isvector(tdata.ystd) && length(tdata.ystd)==length(tdata.x))))
                msgbox('Error: std(y) must be empty (for no weights) or a vector of the same length as y.');
                return;
            end
            
            % Force row vectors
            tdata.x = tdata.x(:)';
            tdata.y = tdata.y(:)';
            tdata.ystd = tdata.ystd(:)';

            % fitting range
            if isempty(data.fitrangename)
                tdata.fitrange = true(size(tdata.x));
            else
                try
                    tdata.fitrange = quickfit.Engine.evalXY(tdata.x,tdata.y,tdata.ystd,1:length(tdata.x), data.fitrangename);
                    if size(tdata.fitrange) == size(tdata.x)
                        % Assume logical (e.g. "x > 10");
                        tdata.fitrange = logical(tdata.fitrange);
                    else
                        % Maybe it is an index? e.g. 1:10
                        if isvector(tdata.fitrange) && all(tdata.fitrange > 1) && all(tdata.fitrange <= length(tdata.x))
                            % Convert to logical index
                            ti = false(size(tdata.x)); 
                            ti(tdata.fitrange) = true;
                            tdata.fitrange = ti;
                        else
                            msgbox('Error: fitting range must return a logical with the same size as x, or valid indices.');
                        end
                    end
                catch me
                    msgbox(['Error evaluating fitting range: ',me.message]);
                    return;
                end
            end
            if ~any(tdata.fitrange)
                msgbox('Warning: No x values lie within fitting range.')
            end
            
            % Reset removed points
            tdata.removedpoints = false(size(tdata.x));

            % x model data for smooth plotting
            if isempty(data.xmodelname)
                tdata.xmodel = tdata.x;
            else
                try
                    tdata.xmodel = quickfit.Engine.evalXY(tdata.x,tdata.y,tdata.ystd,1:length(tdata.x), data.xmodelname);
                catch me
                    msgbox(['Error evaluating x for plotting: ',me.message]);
                    return;
                end
            end
            
            % All data seems to be valid! Now we can copy it over to
            % settings
            data.x = tdata.x;
            data.y = tdata.y;
            data.ystd = tdata.ystd;
            data.fitrange = tdata.fitrange;
            data.removedpoints = tdata.removedpoints;
            data.xmodel = tdata.xmodel;
            
            obj.plotData();
        end
        
        % Set data programmatically, for example when initializing
        function setData(obj, x,y,ystd,xname,yname,ystdname)
            if nargin<4, ystd = []; end;
            if nargin<5 || isempty(xname), xname = '<Data>'; end;
            if nargin<6 || isempty(yname), yname = '<Data>'; end;
            if nargin<7 || isempty(ystdname)
                if isempty(ystd)
                    ystdname = '';
                else
                    ystdname = '<Data>'; 
                end;
            end
            
            % set data
            data = obj.settings.session.data;
            data.xname = xname;
            data.x = x;
            data.yname = yname;
            data.y = y;
            data.ystdname = ystdname;
            data.ystd = ystd;
            
            % Apply data wihtout re-evaluating
            obj.dataApply(true);
        end
        
        function plotData(obj)
            data = obj.settings.session.data;
            
            % Clear all traces
            obj.clearTraces();
            
            if ~isempty(data.x)
                % Add new data trace and plot
                dx = data.x; dy = data.y; 
                if any(data.removedpoints) || any(~data.fitrange)
                    obj.addTrace(dx, dy, 'datagray');
                    
                    dx(data.removedpoints) = nan; dx(~data.fitrange) = nan;
                    dy(data.removedpoints) = nan; dy(~data.fitrange) = nan;
                end
                obj.addTrace(dx, dy, 'data');
                if ~isempty(data.ystd) 
                    flat = @(x) x(:);
                    ystdx = flat([data.x;data.x;nan(size(data.x))]);
                    ystdy = flat([data.y-data.ystd;data.y+data.ystd;nan(size(data.y))]);
                    obj.addTrace(ystdx,ystdy,'ystd');
                end
            end
                        
            obj.ui.updatePlots();
        end
        
        function plotInitials(obj)
            obj.clearTraces('initials');
            
            session = obj.settings.session;
            data = session.data;
            fit = session.fit;           

            % No data?
            if isempty(data.xmodel);
                return; 
            end
            
            % Make fit function
            thefun = quickfit.Engine.makeFitFunction(session.function, fit.initials, zeros(size(fit.initials)));
            
            obj.addTrace(data.xmodel, thefun(fit.initials, data.xmodel), 'initials');
            
            obj.ui.updatePlots();
        end
        
        function doFit(obj)
       %     try
                obj.clearTraces('fit','fitconfidence','residual');
                           
                session = obj.settings.session;
                data = session.data;
                fit = session.fit;

                % No data?
                if isempty(data.x) || ...
                        isempty(data.y) || ...
                        isempty(data.fitrange);
                    return; 
                end

                % Checks
                if all(session.fit.fixedparams)
                    msgbox('There are no free parameters.');
                    return;
                end

                % Get data (considering fitrange and removedpoints)
                xdata = session.data.x(session.data.fitrange & (~session.data.removedpoints));
                ydata = session.data.y(session.data.fitrange & (~session.data.removedpoints));
                if ~isempty(session.data.ystd)
                    ystddata = session.data.ystd(session.data.fitrange & (~session.data.removedpoints));
                else
                    ystddata = ones(size(ydata));
                end

                % Remove NaN values
                nans = isnan(xdata) | isnan(ydata);
                xdata = xdata(~nans);
                ydata = ydata(~nans);
                ystddata = ystddata(~nans);


                % Reduce variables to exclude fixed parameters
                initialsshort = fit.initials(~fit.fixedparams);
                lbshort = fit.lb(~fit.fixedparams);
                ubshort = fit.ub(~fit.fixedparams);
                
                % Scaled parameters
                if session.fitting.scaleparameters
                    paramscale = initialsshort; paramscale(paramscale == 0) = 1;
                    initialsshort = initialsshort./paramscale;
                else
                    paramscale = ones(size(initialsshort));
                end

                % Make fit function
                thefun = quickfit.Engine.makeFitFunction(session.function, fit.initials, fit.fixedparams, paramscale);

                fitoptions = session.fitting.options.getStructData();

                algorithm = session.fitting.algorithm;            
                if strcmp(algorithm,'lsqcurvefit')
                    disp('Warning: std(y) will be ignored.')
                    if any(ystddata ~= 1)
                        waitfor(msgbox('The selected algorithm (lsqcurvefit) does not support weighted fitting (std(y) is ignored).','Warning','warn'));
                    end
                    [outputparamsraw,~,RESIDUAL,EXITFLAG,~,~,JACOBIAN]=lsqcurvefit(thefun, initialsshort,xdata,ydata,lbshort,ubshort,optimset(fitoptions));
                elseif strcmp(algorithm,'lsqnonlin')
                    lsqnonlinfun = @(p)(thefun(p,xdata) - ydata)./ystddata;
                    [outputparamsraw,~,RESIDUAL,EXITFLAG,~,~,JACOBIAN]=lsqnonlin(lsqnonlinfun,initialsshort,lbshort,ubshort,optimset(fitoptions));
                elseif strcmp(algorithm,'nlinfit')
                    disp('Warning: std(y) and lower/upper bound will be ignored.');
                    if any(ubshort < inf) || any(lbshort > -inf)
                        waitfor(msgbox('The selected algorithm (nlinfit) does not support upper and lower bounds.','Warning','warn'));
                    end
                    if any(ystddata ~= 1)
                        waitfor(msgbox('The selected algorithm (nlinfit) does not support weighted fitting (std(y) is ignored).','Warning','warn'));
                    end
                    [outputparamsraw,RESIDUAL,JACOBIAN,~,~] = nlinfit(xdata,ydata,thefun,initialsshort);
                elseif strcmp(algorithm,'fmincon')
                    fminconfun = @(p)(sum(((thefun(p,xdata) - ydata)./ystddata).^2));
                    [outputparamsraw,~,EXITFLAG] = fmincon(fminconfun,initialsshort,[],[],[],[],lbshort,ubshort,[],optimset(fitoptions));
                elseif strcmp(algorithm,'fminsearch')
                    disp('Warning: lower/upper bound will be ignored.');
                    if any(ubshort < inf) || any(lbshort > -inf)
                        waitfor(msgbox('The selected algorithm (fminsearch) does not support upper and lower bounds.','Warning','warn'));
                    end
                    fminconfun = @(p)(sum(((thefun(p,xdata) - ydata)./ystddata).^2));
                    [outputparamsraw,~,EXITFLAG] = fminsearch(fminconfun,initialsshort,optimset(fitoptions));
                else
                    msgbox('Unsupported algorithm.');
                    return;
                end
                
                % Map variable and fixed output parameters back together
                % (and undo parameter scaling)
                s = struct('type','()', 'subs',{{find(~fit.fixedparams)}});
                fit.results = subsasgn(fit.initials,s,outputparamsraw.*paramscale);

                % Notify the user if the fit did not converge
                if exist('EXITFLAG','var') && EXITFLAG <= 0
                    uiwait(msgbox(['Fit did not converge. Reason: ',quickfit.Engine.getLsqcurvefitExitflag(EXITFLAG)]));
                end

                % Calculate confidence bounds (try/catch because it may fail for some (usually bad) fits (e.g. with complex parameters)
                conf=NaN(length(fit.fixedparams),2);
                if session.fitting.paramconfidence
                    if exist('JACOBIAN','var')
                        try
                            % Specify alpha=0.31... for 1 sigma confidence bound (I think nlparci assumes normal statistics anyway)
                            confT = nlparci(outputparamsraw,RESIDUAL,'jacobian',JACOBIAN,'alpha',(1-erf(1/sqrt(2))));
                            %confT = nlparci(outputparamsraw,RESIDUAL,'covar',COVB,'alpha',1-erf(1/sqrt(2)));  % Alternative syntax when using nlinfit. Only different if 'robust' option is used in nlinfit.

                            confT(:,1) = confT(:,1).*paramscale';
                            confT(:,2) = confT(:,2).*paramscale';
                            conf(~fit.fixedparams,:) = confT(1:length(outputparamsraw),:);
                        catch e
                            disp(['Error calculating confidence bounds: ',e.message]);
                        end
                    end
                end
                % Assume symmetric bounds (I have never seen other asymmetric results, maybe with different algorithms you get them)
                % (and undo parameter scaling)
                fit.confidence = (conf(:,2)'-conf(:,1)')/2;

                if session.fitting.predconfidence
                    if exist('JACOBIAN','var')
                        % Calculate vertical uncertainty   
                        % (not affected by paramter scaling, because the function is evaluated in scaled paramters)
                        try
                            [ypred,delta] = nlpredci(thefun,data.xmodel,outputparamsraw,RESIDUAL,'jacobian',JACOBIAN,'alpha',1-erf(1/sqrt(2)));
                            obj.addTrace(data.xmodel, ypred + delta, 'fitconfidence');
                            obj.addTrace(data.xmodel, ypred - delta, 'fitconfidence');
                        catch e
                            disp(['Error calculating vertical confidence bounds: ',e.message]);
                            % Calculated ypred separately
                            ypred = thefun(outputparamsraw, data.xmodel);
                        end
                    else
                        % Calculated ypred separately
                        ypred = thefun(outputparamsraw, data.xmodel);
                    end
                else
                    % Calculated ypred separately
                    ypred = thefun(outputparamsraw, data.xmodel);                   
                end

                % Create fit result text for export
                ftext = sprintf('%s: y = %s\n', session.function.name,session.function.equation);
                fit.resulttext = [ftext, quickfit.Engine.formatresults(fit.results, fit.confidence, session.function.parameters, fit.fixedparams, true)];
                
                % Print fit results to command window
                fprintf('************************ Fit Results ************************\n');
                fprintf(ftext);
                disp(quickfit.Engine.formatresults(fit.results, fit.confidence, session.function.parameters, fit.fixedparams, false));
                fprintf('(Listed uncertainties are 68%% confidence intervals)\n');
                if exist('EXITFLAG','var'), fprintf('Exit condition: %s\n',quickfit.Engine.getLsqcurvefitExitflag(EXITFLAG)); end;
                fprintf('*************************************************************\n');

                % Plot fit result
                obj.addTrace(data.xmodel, ypred, 'fit', fit.resulttext);
                
                % Create residual trace
                obj.addTrace(data.x, data.y - thefun(outputparamsraw, data.x),'residual');
                
%             catch e
%                 disp(['Error during fit: ' e.message]);
%             end
              obj.ui.updatePlots();
        end
        
        % Add a new trace
        function addTrace(obj,x,y,type,report,legendname)
            if ~exist('legendname','var'), legendname = iif(length(type)>1,[upper(type(1)) type(2:end)],upper(type)); end;
            if ~exist('report','var'), report = ''; end;

            plotstyle = struct(obj.settings.ui.plotstyles.(type){:});
            
            %data datagray fit fitconfidence initials ystd residual
            switch type
                case {'datagray','fitconfidence','initials','ystd'}
                    m = true; e = false; l = false; r = false;
                case {'residual'}
                    m = false; e = false; l = false; r = true;
                otherwise
                    m = true; e = true; l = true; r = false;
            end
            
            % Trace structure
            t = struct(...
                'x',x,...
                'y',y,...
                'type',type,...
                'legendname',legendname,...
                'plotstyle',plotstyle,...
                'enabled', struct(...
                    'main',m,...
                    'export',e,...
                    'legend',l,...
                    'residual',r...
                ),...
                'report',report...
            );
        
            % Add
            if isempty(obj.settings.session.traces)
                obj.settings.session.traces = t;
            else
                obj.settings.session.traces(end+1) = t;
            end
            
            function result = iif(condition,trueResult,falseResult)
                if condition
                    result = trueResult;
                else
                    result = falseResult;
                end
            end
        end
        
        function clearTraces(obj, varargin)
            if nargin > 1
                % Clear specified traces
                toclear = arrayfun(@(t)any(strcmp(t.type,varargin)),obj.settings.session.traces);
                obj.settings.session.traces = obj.settings.session.traces(~toclear);
            else
                % Clear ALL traces
                obj.settings.session.traces = [];
            end
        end
    end
 
    methods (Access = protected)
        function s = initializeSettings(obj, filename)
            s = obj.defaultSettings();
            [s.session.fitting.algorithm,obj.availableAlgorithms] = quickfit.Engine.getDefaultAlgorithm();
            if nargin>1 && ~isempty(filename)
                if exist(filename,'file')
                    saved = load(filename);
                    if isfield(saved,'info') && isstruct(saved.info) && isfield(saved.info, 'type') && strcmp(saved.info.type,'QuickfitSettings') && isfield(saved,'settings')
                        s.putStructData(saved.settings, false, true);
                    else
                        disp('WARNING: Settings file does not seem to contain valid quickfit settings data. Starting with hard-coded defaults.');
                    end
                else
                    disp('WARNING: Settings file does not exist. Starting with hard-coded defaults.');
                end
                s.settingsFile = filename;
            else
                disp('WARNING: No settings file specified. Starting with hard-coded defaults, and settings will not be saved.');
            end
        end
    end
    methods (Static)   
        % This function defines which settings exist, and what their
        % hardcoded default values are
        function s = defaultSettings()
            s = cfw.Settings;
            
            s.addSetting('settingsFile','');
            
            % Function library (some default functions)
            slib = cfw.Settings;
            
                sf = cfw.Settings;
                    sf.addSetting('name','Sine');
                    sf.addSetting('description','Sine');
                    sf.addSetting('parameters',{'a'  'k'  'phi'  'o'});
                    sf.addSetting('initials','[1 1 0 0]');
                    sf.addSetting('equation','a * sin(2*pi*k*x + phi) + o');
                slib.addSetting(sf.name,sf);
                
                sf = cfw.Settings;
                    sf.addSetting('name','Gaussian');
                    sf.addSetting('description','Amplitude-normalized Gaussian');
                    sf.addSetting('parameters',{'a'  'w'  'x0'  'o'});
                    sf.addSetting('initials','[1 1 0 0]');
                    sf.addSetting('equation','a * exp(-(x-x0).^2/(2*w^2)) + o');
                slib.addSetting(sf.name,sf);
                
                sf = cfw.Settings;
                    sf.addSetting('name','Exponential');
                    sf.addSetting('description','Exponential growth');
                    sf.addSetting('parameters',{'a'  'b'  'o'});
                    sf.addSetting('initials','[1 1 0]');
                    sf.addSetting('equation', 'a*exp(b*x) + o');
                slib.addSetting(sf.name,sf);
                
                sf = cfw.Settings;
                    sf.addSetting('name','Powerlaw');
                    sf.addSetting('description','General power law');
                    sf.addSetting('parameters',{'a'  'b'  'c'});
                    sf.addSetting('initials','[1 1 0]');
                    sf.addSetting('equation', 'b*x.^a + c');
                slib.addSetting(sf.name,sf);
                
                sf = cfw.Settings;
                    sf.addSetting('name','Lorentzian');
                    sf.addSetting('description','Amplitude-normalized Lorentzian, FWHM');
                    sf.addSetting('parameters',{'a'  'w'  'x0', 'o'});
                    sf.addSetting('initials','[1 1 0 0]');
                    sf.addSetting('equation', 'a*(w/2)^2./((x-x0).^2 + (w/2)^2)+o');
                slib.addSetting(sf.name,sf);
                
            s.addSetting('functions',slib);
            
            % Session
            ss = cfw.Settings;
            
                % Currently active function (not saved in library unless the 'save' button is clicked)
                ss.addSetting('function', quickfit.Engine.getDefaultFunction);
                
                % Fit initials, results, etc
                sg = cfw.Settings;
                    sg.addSetting('initials', []);
                    sg.addSetting('fixedparams', []);
                    sg.addSetting('lb',[]);
                    sg.addSetting('ub',[]);
                    sg.addSetting('results',[]);
                    sg.addSetting('confidence',[]);
                    sg.addSetting('function', []); % This is filled in when a fit is performed.
                    sg.addSetting('resulttext','');
                ss.addSetting('fit',sg);
                
                % Data
                sd = cfw.Settings;
                    % These parameters contain the current data, as updated
                    % in DataApply.
                    sd.addSetting('x', []);
                    sd.addSetting('y', []);
                    sd.addSetting('ystd', []);
                    sd.addSetting('xmodel',[]);
                    sd.addSetting('fitrange', []);       % Range
                    sd.addSetting('removedpoints', []);
                    % These parameters reflect the contents of the
                    % corresponding text box:
                    sd.addSetting('xname', '');
                    sd.addSetting('yname', '');
                    sd.addSetting('ystdname', '');
                    sd.addSetting('xmodelname','linspace(min(x), max(x), 1000)'); % expression for model x (as function of x)
                    sd.addSetting('fitrangename','');
                ss.addSetting('data', sd);
                
                ss.addSetting('traces',[]);
                
                % State machine
                sstate = cfw.Settings;
                    sstate.addSetting('functionchanged',true);
                ss.addSetting('state',sstate);
            
                % Fit settings
                sfit = cfw.Settings;

                    % Default fit options
                    sopt = cfw.Settings;
                        sopt.addSetting('Display','final','description','Values: off,iter,final,notify');
                        sopt.addSetting('TolFun', 1e-6, 'description','Tolerance in y','editclass','double');
                        sopt.addSetting('TolX', 1e-6 , 'description','Tolerance in x','editclass','double');
                        sopt.addSetting('MaxFunEvals', 2000,'description', 'Maximum number of function evaluations','editclass','int32');  % Default is 100*numberOfVariables. I guess a typical function with this tool uses 4 or so (for more you probably need to fix a few at first, and they don't count)
                        sopt.addSetting('MaxIter', 2000, 'description','Maximum number of iterations','editclass','int32');        % Default is 400, but this is most often limiting
                        sopt.addSetting('DiffMaxChange',Inf,'description','Maximum change in variables for finite-difference gradients','editclass','double');
                        sopt.addSetting('DiffMinChange',0,'description','Minimum change in variables for finite-difference gradients','editclass','double');
                    sfit.addSetting('options',sopt);

                    % Fit routine
                    sfit.addSetting('algorithm','','allowload',false); % This will be set automatically on start-up
                    sfit.addSetting('scaleparameters',false,'editclass','logical','description','Scale parameters by initial values during fitting');
                    sfit.addSetting('paramconfidence',true,'editclass','logical','description','Calculate parameter confidence bounds');
                    sfit.addSetting('predconfidence',false,'editclass','logical','description','Calculate prediction confidence bound');

                ss.addSetting('fitting',sfit);
                
                % Export settings
                se = cfw.Settings;
                    se.addSetting('title','');
                    se.addSetting('xlabel','');
                    se.addSetting('ylabel','');
                    se.addSetting('showfitresults',true,'editclass','logical');
                    se.addSetting('showlegend',false,'editclass','logical');
                    se.addSetting('showresiduals',false,'editclass','logical');
                ss.addSetting('export',se);
                
            s.addSetting('session',ss,'allowload',false);
            
            sui = cfw.Settings;
                sps = cfw.Settings;
                    sps.addSetting('data',          {'Color',[0.2  0.2 0.8], 'LineStyle', '-', 'LineWidth', 1,   'Marker','d',   'MarkerSize', 4,'MarkerFaceColor',[0.2 0.2 0.8]});
                    sps.addSetting('datagray',      {'Color',[0.7  0.7 0.7], 'LineStyle', '-', 'LineWidth', 1,   'Marker','d',   'MarkerSize', 4,'MarkerFaceColor',[0.7 0.7 0.7]});
                    sps.addSetting('fit',           {'Color',[0.95 0.1 0  ], 'LineStyle', '-', 'LineWidth', 1.5, 'Marker','none'});
                    sps.addSetting('fitconfidence', {'Color',[0.95 0.1 0  ], 'LineStyle', ':', 'LineWidth', 0.5, 'Marker','none'});
                    sps.addSetting('initials',      {'Color',[0    0.9 0.1], 'LineStyle', '-', 'LineWidth', 1,   'Marker','none'});
                    sps.addSetting('ystd',          {'Color',[0.2  0.2 0.8], 'LineStyle', '-', 'LineWidth', 1,   'Marker','none'});
                    sps.addSetting('residual',      {'Color',[0.2  0.2 0.8], 'LineStyle', '-', 'LineWidth', 1,   'Marker','d',   'MarkerSize', 4,'MarkerFaceColor',[0.2 0.2 0.8]});
                    
                sui.addSetting('plotstyles',sps);
                
            s.addSetting('ui',sui);
            
        end
    end
end