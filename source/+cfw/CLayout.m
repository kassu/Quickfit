classdef CControl < handle
    properties
        parent = [];
        window = [];
        units = 'normalized';
        position = [0 0 1 1];
        absunits = 'pixels';
        absposition = [0 0 1 1];
    end
    methods
        %%%%%%%%%%%%%% Constructor
        function obj = CControl(mywindow, myparent)
            if nargin>0 && ~isempty(mywindow)
                obj.parent = myparent;
            else
                throw(MException('CControl:constructor', 'Control must be created with a CWindow as first argument.'));
            end
            if nargin>1 && ~isempty(myparent)
                obj.parent = myparent;
            end
        end
        %%%%%%%%%%%%%%% Parent/child hierarchy
        function set.window(obj,value)
            if isa(value,'cfw.CWindow')
                obj.window = value;
                value.addChild(obj);
            else
                throw(MException('CControl:set.window', 'Window must be a CWindow class'));
            end
        end
        function set.parent(obj,value)
            if isempty(value)
                obj.parent = [];
            elseif isa(value,'cfw.CControl')
                obj.parent = value;
                value.addChild(obj);
            else
                throw(MException('CControl:set.parent', 'Parent must be empty or a CControl class'));
            end
        end
        function addChild(obj,value)
            if isa(value,'cfw.CControl')
                if isempty(obj.children)
                    obj.children = value;
                else
                    obj.children(end+1) = value;
                end
            else
                throw(MException('CControl:addChild', 'Child must be a CControl class'));
            end
        end
        function removeChild(obj,value)
            if isa(value,'cfw.CControl')
                obj.children = obj.children(obj.children~=value);
            else
                throw(MException('CControl:removeChild', 'Child must be a CControl class'));
            end
        end
        %%%%%%%%%%%%%%% Positioning within parent
        function set.units(obj,value)
            if ischar(value) && any(strcmpi(value,{'normalized'}))
                obj.units = value;
            else
                throw(MException('CControl:set.units', 'Only normalized units are currently supported.'));
            end
        end
        function set.position(obj,value)
            if isnumeric(value) && isequal(size(value),[1 4])
                obj.position = value;
                obj.resize;
            else
                throw(MException('CControl:set.position', 'Position must be a numeric 1x4 value.'));
            end
        end
        %%%%%%%%%%%%%%% Resize the object
        function resize(obj)
            % This function must be overwritten in derived classes
        end
	end
end