classdef CWindow < handle
    properties
        parent              % Parent window, or []
        children            % Child windows
        hfigure             % Handle to the corresponding matlab figure
        control             % Reference to the top level control
        controls = struct;  % Flat list of named controls. Not all controls have to be added
    end
    events
        Close
        Delete
    end
    methods
        %%%%%%%%%%%%%% Constructor
        function obj = CWindow(myparent)
            if nargin>0 && ~isempty(myparent)
                obj.parent = myparent;
            end
            obj.hfigure = figure(...
                'CloseRequestFcn',@obj.cb_CloseRequestFcn,...
                'DeleteFcn',@obj.cb_DeleteFcn,...
                'ResizeFcn',@obj.cb_ResizeFcn,...
                'HandleVisibility','off',...
                'IntegerHandle','off',...
                'NumberTitle','off',...
                'ToolBar','none',...
                'MenuBar','none',...
                'Color',get(0,'defaultUicontrolBackgroundColor'),...
                'Visible','off');
        end
        function delete(obj)
            notify(obj,'Delete')
            if ~isempty(obj.control)&& isvalid(obj.control), delete(obj.control); end
            if ~isempty(obj.hfigure) && ishandle(obj.hfigure)
                delete(obj.hfigure)
            end
            for i = 1:length(obj.children)
                if isvalid(obj.children(i)), delete(obj.children(i)); end;
            end
        end 
        %%%%%%%%%%%%%%% Basic functions
        function set(obj,name,value)
            set(obj.hfigure,name,value);
        end
        function value = get(obj,name)
            value = get(obj.hfigure,name);
        end
        function show(obj)
            set(obj.hfigure,'Visible','on');
        end
        function hide(obj)
            set(obj.hfigure,'Visible','off');
        end
        %%%%%%%%%%%%%%% Top level control
        function set.control(obj,value)
            if isa(value,'cfw.CControl')
                obj.control = value;
                value.parent = [];
                value.setWindow(obj);
                value.placeControl();
            else
                throw(MException('CWindow:set.control', 'Control must be a CControl-derived class'));
            end
        end
        %%%%%%%%%%%%%%% Named controls
        function addNamedControl(obj,name,value)
            if isa(value,'cfw.CControl')
                obj.controls.(name) = value;
            else
                throw(MException('CWindow:addNamedControl', 'Control must be a CControl-derived class'));
            end
        end
        function removeNamedControl(obj,name)
            if ischar(name) && isfield(obj.controls,name)
                obj.controls = rmfield(obj.controls,name);
            end
        end
        %%%%%%%%%%%%%%% Parent/child hierarchy
        function set.parent(obj,value)
            if isa(value,'cfw.CWindow')
                obj.parent = value;
                value.addChild(obj);
            else
                throw(MException('CWindow:set.parent', 'Parent must be a CWindow class'));
            end
        end
        function addChild(obj,value)
            if isa(value,'cfw.CWindow')
                if isempty(obj.children)
                    obj.children = value;
                else
                    obj.children(end+1) = value;
                end
            else
                throw(MException('CWindow:addChild', 'Child must be a CWindow class'));
            end
        end
        function removeChild(obj,value)
            if isa(value,'cfw.CWindow')
                obj.children = obj.children(obj.children~=value);
            else
                throw(MException('CWindow:removeChild', 'Child must be a CWindow class'));
            end
        end
        %%%%%%%%%%%%%% Callback functions from the figure
        function cb_CloseRequestFcn(obj,src,evt)
            notify(obj,'Close');
            if isvalid(obj) && ~isempty(obj.hfigure) && ishandle(obj.hfigure), delete(obj.hfigure); end;
        end
        function cb_DeleteFcn(obj,src,evt)
            if isvalid(obj)
                obj.hfigure = [];
                delete(obj);
            end
        end
        function cb_ResizeFcn(obj,src,evt)
            if ~isempty(obj.control) && isa(obj.control,'cfw.CControl')
                old_units = get(obj.hfigure,'Units');
                set(obj.hfigure,'Units','pixels');
                p = get(obj.hfigure,'Position');
                obj.control.resize('pixels',[1 1 p(3) p(4)]);
                set(obj.hfigure,'Units',old_units);
            end
        end
	end
end