classdef SettingChangedEvent < event.EventData
    properties
        source
        name
        oldvalue
        newvalue
    end
    methods
        function obj = SettingChangedEvent(source,name,oldvalue,newvalue)
            obj.source = source;
            obj.name = name; 
            obj.oldvalue = oldvalue;
            obj.newvalue = newvalue;
        end
    end
end