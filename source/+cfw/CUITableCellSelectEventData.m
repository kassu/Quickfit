classdef CUITableCellSelectEventData < event.EventData
    properties
        row
        column
    end
    methods
        function obj = CUITableCellSelectEventData(row,column)
            obj.row = row;
            obj.column = column; 
        end
    end
end