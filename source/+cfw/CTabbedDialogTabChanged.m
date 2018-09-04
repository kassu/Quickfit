classdef CTabbedDialogTabChanged < event.EventData
    properties
        oldtab
        newtab
    end
    methods
        function obj = CTabbedDialogTabChanged(oldtab,newtab)
            obj.oldtab = oldtab;
            obj.newtab = newtab; 
        end
    end
end