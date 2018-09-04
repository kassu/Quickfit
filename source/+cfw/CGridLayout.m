classdef CGridLayout < cfw.CControl
    properties(SetAccess = protected)
        rows = 1;
        columns = 1;
        rowunits = {'normalized'};
        columnunits = {'normalized'};
    end
    properties
        margin = [2 2 2 2];              % left, bottom, right, top
        marginunits = 'pixels';          % always pixels
    end
    methods
        function obj = CGridLayout(varargin)
            obj = obj@cfw.CControl(varargin{:});
        end
        function setRows(obj,units,sizes)
            if isempty(units)
                units = cell([1,length(sizes)]);
                units(:) = {'normalized'};
            end
            if ~isequal(size(sizes),size(units)) || size(sizes,1)~=1
                throw(MException('CGridLayout:setRows','Units and sizes must be vectors of the same size.'));
            end
            for i=1:length(sizes)
                if ~ischar(units{i}) || ~any(strcmpi(units{i},{'normalized','pixels'}))
                    throw(MException('CGridLayout:setRows','Units must be normalized or pixels.'));
                end
                if ~isnumeric(sizes(i))
                    throw(MException('CGridLayout:setRows','Sizes must be numeric'));
                end
            end
            obj.rowunits = units;
            obj.rows = sizes;
        end
        function setColumns(obj,units,sizes)
            if isempty(units)
                units = cell([1,length(sizes)]);
                units(:) = {'normalized'};
            end
            if ~isequal(size(sizes),size(units)) || size(sizes,1)~=1
                throw(MException('CGridLayout:setColumns','Units and sizes must be vectors of the same size.'));
            end
            for i=1:length(sizes)
                if ~ischar(units{i}) || ~any(strcmpi(units{i},{'normalized','pixels'}))
                    throw(MException('CGridLayout:setColumns','Units must be normalized or pixels.'));
                end
                if ~isnumeric(sizes(i))
                    throw(MException('CGridLayout:setColumns','Sizes must be numeric'));
                end
            end
            obj.columnunits = units;
            obj.columns = sizes;
        end
        function p = makeChildProps(obj,childobj,location,span)
            if nargin >= 3 
                if isequal(size(location),[1 2]) && isnumeric(location) && all(location >= [1 1]) && all(location <= [length(obj.rows) length(obj.columns)])
                    p = struct('location',location,'span',[1 1]);
                    if nargin >=4 
                        if isequal(size(span),[1 2]) && isnumeric(span) && all(span >= [1 1]) && all(span <= [length(obj.rows)-location(1)+1 length(obj.columns)-location(2)+1])
                            p.span = span;
                        else
                            throw(MException('CGridLayout:makeChildProps','Span invalid'));
                        end
                    end
                else
                    throw(MException('CGridLayout:makeChildProps','Location invalid'));
                end
            else
                p = struct('location',[1 1],'span',[1 1]);
            end
        end                
        function setLocation(obj,childobj,varargin)
            a = find(cellfun(@(x)x==childobj,obj.children));
            if length(a) == 1;
                obj.childprops(a) = obj.makeChildProps(childobj,varargin{:});
            else
                throw(MExceptin('CGridLayout:setLocation',sprintf('%d children found',length(a))));
            end
        end
        function resize(obj,units,position)
            % Call super's resize, but don't let it resize the controls
            resize@cfw.CControl(obj,units,position,true);
            
            % %%% Make absolute units for row and column positions
            
            % My position in abs units
            mypos = obj.makeAbsPosition(units,position);
            
            % Sum of normalized units (it is not required to be 1)
            nrows = strcmpi(obj.rowunits,'normalized');
            nrowsum = sum(obj.rows(nrows));
            ncols = strcmpi(obj.columnunits,'normalized');
            ncolsum = sum(obj.columns(ncols));

            % Sum of pixel units
            prows = ~nrows;
            prowsum = sum(obj.rows(prows));
            pcols = ~ncols;
            pcolsum = sum(obj.columns(pcols));
            
            absrows = obj.rows;
            abscols = obj.columns;
            absrows(nrows) = (mypos(4)-prowsum)/nrowsum*obj.rows(nrows);
            abscols(ncols) = (mypos(3)-pcolsum)/ncolsum*obj.columns(ncols);
            absrpos = [0 cumsum(absrows(1:end-1))];
            abscpos = [0 cumsum(abscols(1:end-1))];
            
            for i=1:length(obj.children)
                loc = obj.childprops(i).location;
                span = obj.childprops(i).span;
                x = mypos(1) + abscpos(loc(2)) + obj.margin(1);
                y = mypos(2) + absrpos(loc(1)) + obj.margin(2);
                w = max(obj.children{i}.minsize(1), -abscpos(loc(2)) + abscpos(loc(2)+span(2)-1) + abscols(loc(2)+span(2)-1) - obj.margin(1) - obj.margin(3));
                h = max(obj.children{i}.minsize(2), -absrpos(loc(1)) + absrpos(loc(1)+span(1)-1) + absrows(loc(1)+span(1)-1) - obj.margin(2) - obj.margin(4));
                obj.children{i}.resize(units,[x y w h]);
            end
        end
    end
end
        