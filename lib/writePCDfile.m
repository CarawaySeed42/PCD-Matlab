function pcd = writePCDfile(pcd, filename)
%function writePCDfile(pcd, filename)
% Writes point clouds to a PCD file
%
% Almost no input checking is done. Make sure all the necessary fields
% exist and are populated. Size and Type of fields are derived from matlab
% type. Size and type set by user will be ignored. To change them change
% pcd.header.matlab_type instead.
%
% INPUTS:
%   - pcd [struct]          : A structure containing the point cloud data
%   - filename [string]     : Path to the PCD file to write to
%
% EXAMPLE USAGE:
%   writePCDfile(pcd, 'my_point_cloud.pcd');

if nargin == 1
    error('ERROR: Filename must be specified.');
end

% Check that required fields are present
if ~isfield(pcd, 'header')
    error('ERROR: Input structure does not contain header fields.');
end

% Create file
fid = fopen(filename, 'w');
if (fid == -1)
    error('ERROR: Could not create file "%s".', filename);
end

MException = []; % Empty Matlab Exception
try
    % Set size and type from specified matlab type
    pcd = set_pcd_size_and_type(pcd);
    
    % write Header
    pcd = writePCDheader(pcd, fid);
    
    % Write data
    pcd = writePCDdata(pcd, fid);
    
catch MException
end

% Close the PCD file, even if exception was thrown
if fid ~= -1
    fclose(fid);
end

% If Exception was thrown then throw it again after all files are closed
if ~isempty(MException)
    rethrow(MException);
end
end

function pcd = writePCDheader(pcd, fid)

% Write header
% Version
fprintf(fid, '# .PCD v.7 - Point Cloud Data file format\n');
fprintf(fid, 'VERSION %.1f\n', pcd.header.version);

% Fields
fprintf(fid, 'FIELDS ');
for i = 1:numel(pcd.header.fields)
    fprintf(fid, '%s ', pcd.header.fields{i});
end
fprintf(fid, '\n');

% Sizes
fprintf(fid, 'SIZE ');
for i = 1:numel(pcd.header.size)
    fprintf(fid, '%d ', pcd.header.size(i));
end
fprintf(fid, '\n');

% Types
fprintf(fid, 'TYPE');
for i = 1:numel(pcd.header.type)
    fprintf(fid, ' %c', pcd.header.type(i));
end
fprintf(fid, '\n');

% Counts
fprintf(fid, 'COUNT');
for i = 1:numel(pcd.header.count)
    fprintf(fid, ' %d', pcd.header.count(i));
end
fprintf(fid, '\n');

% Height and Width
if isfield(pcd.header, 'width') && isfield(pcd.header, 'height')
    fprintf(fid, 'WIDTH %d\n', pcd.header.width);
    fprintf(fid, 'HEIGHT %d\n', pcd.header.height);
end

% Viewpoint
if isfield(pcd.header, 'viewpoint')
    fprintf(fid, 'VIEWPOINT %g %g %g %g %g %g %g\n', pcd.header.viewpoint');
end

% Number of Points
if isfield(pcd.header, 'points')
    fprintf(fid, 'POINTS %d\n', pcd.header.points);
end

% Check if width * height is same as in points
if (pcd.header.width * pcd.header.height ~= pcd.header.points)
    error('ERROR: Number of points from width and height do not equal points field');
end

% Data (ascii, binary, binary_compressed)
fprintf(fid, 'DATA %s\n', pcd.header.data);

% Header Size
pcd.header.headerSize = ftell(fid);
end

function pcd = writePCDdata(pcd, fid)

elementsPerLine = sum(pcd.header.count);
bytesPerLine = sum(pcd.header.size.*pcd.header.count);
numPoints = pcd.header.width * pcd.header.height;
fieldCount = numel(pcd.header.fields);

if strcmp(pcd.header.data, 'ascii')
    
    % Create format specifier for fprintf write
    formatSpec = repmat('%g ', 1, elementsPerLine);
    formatSpec(end:end+1) = '\n';
    
    % Create a matrix that contains all data to write as doubles
    data = zeros(elementsPerLine, numPoints, 'double');
    row_counter = 1;
    for i = 1:fieldCount
        row_range = row_counter:row_counter+pcd.header.count(i)-1;
        data(row_range, :) = double(pcd.(pcd.header.fields{i})');
        row_counter = row_counter + pcd.header.count(i);
    end
    
    % Write data
    fprintf(fid, formatSpec, data);
    
elseif strcmp(pcd.header.data, 'binary')
    
    % Create a matrix that contains all data to write as uint8
    data = zeros(bytesPerLine, numPoints, 'uint8');
    row_counter = 1;
    for i = 1:fieldCount
        bytecount = pcd.header.count(i)*pcd.header.size(i);
        row_range = row_counter:row_counter+bytecount-1;
        data(row_range, :) = reshape(typecast(reshape(pcd.(pcd.header.fields{i})', 1, []), 'uint8'), bytecount, []);
        row_counter = row_counter + bytecount;
    end
    
    % Write data
    fwrite(fid, data(:), 'uint8');
    
elseif strcmp(pcd.header.data, 'binary_compressed')
    
    % load .NET assembly and create an instance of CLZF class
    mpath = mfilename('fullpath');
    [path,~,~] = fileparts(mpath);
    CLZF_Assembly_Name = 'CLZF.dll';
    CLZF_Assembly_Fullpath = fullfile(path, CLZF_Assembly_Name);
    CLZF_asm = NET.addAssembly(CLZF_Assembly_Fullpath);
    CLZF_Obj = LZF.NET.CLZF();
    
    pcd.decompressed_size = bytesPerLine*numPoints;
    
    % Create a vector that contains all data to write as uint8
    data = zeros(1,pcd.decompressed_size, 'uint8');
    row_counter = 1;
    for i = 1:fieldCount
        bytecount = pcd.header.count(i)*pcd.header.size(i)*numPoints;
        row_range = row_counter:row_counter+bytecount-1;
        data(row_range) = typecast(reshape(pcd.(pcd.header.fields{i})', 1, []), 'uint8');
        row_counter = row_counter + bytecount;
    end
    
    % compress data
    pcd.compressed_size = CLZF_Obj.lzf_compress(data, length(data), length(data)*1.1);
    data_compressed = uint8(CLZF_Obj.getData());
    compressed_size_check = CLZF_Obj.getDataLength();
    
    if (pcd.compressed_size ~= compressed_size_check || pcd.compressed_size == 0)
        error('ERROR: Data compression failed! Data is too large or otherwise faulty');
    end
    
    % Write data
    fwrite(fid, pcd.compressed_size, '1*uint32');
    fwrite(fid, pcd.decompressed_size, '1*uint32');
    fwrite(fid, data_compressed, 'uint8');
else
    error('ERROR: Data format not supported. Supported formats are ascii, binary, binary_compressed.');
end

end


function pcd = set_pcd_size_and_type(pcd)

type = 'N';
size = 0;

matlabType = pcd.header.matlab_type;
typeCount = numel(matlabType);
pcd.header = rmfield(pcd.header,'type');

for i = 1:typeCount
    
    switch matlabType{i}
        case 'int8'
            type = 'I'; size = 1;
        case 'int16'
            type = 'I'; size = 2;
        case 'int32'
            type = 'I'; size = 4;
        case 'int64'
            type = 'I'; size = 8;
        case 'uint8'
            type = 'U'; size = 1;
        case 'uint16'
            type = 'U'; size = 2;
        case 'uint32'
            type = 'U'; size = 4;
        case 'uint64'
            type = 'U'; size = 8;
        case 'single'
            type = 'F'; size = 4;
        case 'double'
            type = 'F'; size = 8;
        otherwise
            error('ERROR: Matlab type %s invalid.', matlabType{i});
    end
    
    pcd.header.size(i) = size;
    pcd.header.type(i,1) = type;
end

end