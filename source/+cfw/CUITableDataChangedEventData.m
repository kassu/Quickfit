classdef CUITableDataChangedEventData < event.EventData
    properties
        row
        column
        oldvalue
        newvalue
    end
    methods
        function obj = CUITableDataChangedEventData(row,column,oldvalue,newvalue)
            obj.row = row;
            obj.column = column; 
            obj.oldvalue = oldvalue;
            obj.newvalue = newvalue;
        end
    end
end