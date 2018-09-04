classdef CUIButtonGroupSelectionChangedEventData < event.EventData
    properties
        oldvalue
        newvalue
    end
    methods
        function obj = CUIButtonGroupSelectionChangedEventData(oldvalue,newvalue)
            obj.oldvalue = oldvalue;
            obj.newvalue = newvalue;
        end
    end
end