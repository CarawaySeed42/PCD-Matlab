function pcd = readPCDfile(filename, readOption)
%function pcd = readPCDfile(filename, readOption)
% Reads point clouds in PCD format
%
% If a data field has bigger count than one, the resutling data field will be
% a [nxm] matrix, with n = number of points and m = count
%
% INPUTS:
%   - filename [string]     : Path to the PCD file
%   - readOption [string]   : Optional settings
%           'ReadAll'       : Read header and data (default)
%           'Header'        : Read only header
%
% OUTPUTS:
%   - pcd [struct]  : A structure containing the contents of pcd file
%
% EXAMPLE USAGE:
%   pcd = readPCDfile('my_point_cloud.pcd');
%   pcd = readPCDfile('my_point_cloud.pcd', "ReadAll");
%   pcd = readPCDfile('my_point_cloud.pcd', 'Header');
%

if nargin == 1
    readOption = 'ReadAll';
end

fid = -1;
pcd = struct();

MException = []; % Empty Matlab Exception
try
    pcd = read_header(pcd, filename);
    pcd = createDataFields(pcd);
    
    if strcmp(readOption, 'Header')
        return;
    end
    
    % Read data
    if strcmp(pcd.header.data, 'ascii')
        fid = fopen(filename, 'r');
        if (fid == -1)
            error('ERROR: Could not open file "%s".', filename);
        end
        
        % Skip the header
        fseek(fid, pcd.header.headerSize, 'bof');
        
        % Create the formatSpec for text file by adding all the types of fields
        formatSpec = '';
        for i = 1:numel(pcd.header.type)
            currentFormat = repmat([get_formatSpec(pcd.header.type(i)), ' '], 1, pcd.header.count(i));
            formatSpec = [formatSpec, currentFormat];
        end
        
        all_PCD_data = textscan(fid, formatSpec);
        
        % Distribute data to their respective fields
        column_counter = 1;
        for i = 1:numel(pcd.header.fields)
            field = pcd.header.fields{i};
            count = pcd.header.count(i);
            col_range = column_counter:column_counter+count-1;
            pcd.(field) = cast(cell2mat(all_PCD_data(col_range)), pcd.header.matlab_type{i});
            column_counter = column_counter + count;
        end
        
    elseif strcmp(pcd.header.data, 'binary')
        fid = fopen(filename, 'rb');
        if (fid == -1)
            error('ERROR: Could not open file "%s".', filename);
        end
        
        % Skip the header
        fseek(fid, pcd.header.headerSize, 'bof');
        
        % Count bytes per 'line' and number of points
        bytesPerLine = sum(pcd.header.size.*pcd.header.count);
        numPoints = pcd.header.width * pcd.header.height;
        
        % Read the point data
        data = fread(fid, '*uint8');
        data = reshape(data(1:numPoints*bytesPerLine), bytesPerLine, numPoints);
        
        % Distribute data to their respective fields
        column_counter = 1;
        for i = 1:numel(pcd.header.fields)
            field = pcd.header.fields{i};
            bytecount = pcd.header.count(i)*pcd.header.size(i);
            row_range = column_counter:column_counter+bytecount-1;
            raw_field = reshape(data(row_range, :),[],1);
            pcd.(field) = reshape(typecast(raw_field, pcd.header.matlab_type{i}),  pcd.header.count(i), [])';
            column_counter = column_counter + bytecount;
        end
        
    elseif strcmp(pcd.header.data, 'binary_compressed')
        
        % load .NET assembly and create an instance of CLZF class
        mpath = mfilename('fullpath');
        [path,~,~] = fileparts(mpath);
        CLZF_Assembly_Name = 'CLZF.dll';
        CLZF_Assembly_Fullpath = fullfile(path, CLZF_Assembly_Name);
        CLZF_asm = NET.addAssembly(CLZF_Assembly_Fullpath);
        CLZF_Obj = LZF.NET.CLZF();
        
        fid = fopen(filename, 'rb');
        if (fid == -1)
            error('ERROR: Could not open file "%s".', filename);
        end
        
        % Skip the header
        fseek(fid, pcd.header.headerSize, 'bof');
        
        % The body (everything after the header) starts with a 32 bit unsigned
        % binary number which specifies the size in bytes of the data in compressed
        % form. Next is another 32 bit unsigned binary number which specifies the
        % size in bytes of the data in uncompressed form
        pcd.compressed_size = fread(fid, [1 1], '1*uint32');
        pcd.decompressed_size = fread(fid, [1 1], '1*uint32');
        
        % Read the point data
        data = fread(fid, [pcd.compressed_size 1], '*uint8');
        
        % Decompress data
        decomp_byteCount_returned = CLZF_Obj.lzf_decompress(data, length(data), pcd.decompressed_size);
        decomp_data =  uint8(CLZF_Obj.getData())';
        decomp_byteCount =  CLZF_Obj.getDataLength();
        
        if (decomp_byteCount ~= pcd.decompressed_size)
            error('ERROR: Decompression returns less bytes than specified in file!');
        end
        if (decomp_byteCount_returned == 0)
            error('ERROR: Decompression failed and returned zero bytes!');
        end
        
        % Distribute data to their respective fields
        numPoints = pcd.header.width * pcd.header.height;
        current_pos = 1;
        for i = 1:numel(pcd.header.fields)
            field = pcd.header.fields{i};
            bytecountElement = pcd.header.count(i)*pcd.header.size(i);
            bytecountField = bytecountElement * numPoints;
            fieldRange = current_pos:current_pos+bytecountField-1;
            pcd.(field) = reshape(typecast(decomp_data(fieldRange), pcd.header.matlab_type{i})', pcd.header.count(i), [])';
            current_pos = current_pos + bytecountField;
        end
       
    else
        error('ERROR: Only ascii and binary data format are supported for now!');
    end
    
catch MException
end

% Close the PCD file again, even if exception was thrown
if fid ~= -1
    fclose(fid);
end

% If Exception was thrown then throw it again after all files are closed
if ~isempty(MException)
    rethrow(MException);
end
end



function line = find_pcd_header_entry(fid, entryName)
line = fgetl(fid);
entryCharCount = length(entryName);
lineCounter = 0;

while strncmpi(line, entryName, entryCharCount) == 0
    line = fgetl(fid);
    lineCounter = lineCounter + 1;
    if (~ischar(line) || lineCounter > 50)
        error('ERROR: %s field not found. Invalid PCD format.', entryName);
    end
end
end

function pcd = read_header(pcd, filename)
% Open the PCD file for reading
fid = fopen(filename, 'r');
if (fid == -1)
    error('ERROR: Could not open file "%s".', filename);
end

% Read line to get the version
line = find_pcd_header_entry(fid, 'VERSION');
pcd.header.version = sscanf(line, 'VERSION %f');

% Read lines to get line containing fields
line = find_pcd_header_entry(fid, 'FIELDS');

% Parse the fields
headerFields = textscan(line, '%s');
numFields = numel(headerFields{1}) - 1;
pcd.header.fields = cell(1, numFields);
for i = 1:numFields
    pcd.header.fields{i} = headerFields{1}{i + 1};
end

% Sizes
line = find_pcd_header_entry(fid, 'SIZE');
lineTmp = textscan(line, '%s');
pcd.header.size = str2double(lineTmp{1}(2:end));

% Field types
line = find_pcd_header_entry(fid, 'TYPE');
lineTmp = textscan(line, '%s');
pcd.header.type = cell2mat(lineTmp{1}(2:end));

% Get matlab types
pcd = get_matlab_type(pcd);

% Count
line = find_pcd_header_entry(fid, 'COUNT');
lineTmp = textscan(line, '%s');
pcd.header.count = str2double(lineTmp{1}(2:end));

% Width
line = find_pcd_header_entry(fid, 'WIDTH');
pcd.header.width = sscanf(line, 'WIDTH %d');

% Height
line = find_pcd_header_entry(fid, 'HEIGHT');
pcd.header.height = sscanf(line, 'HEIGHT %d');

% Viewpoint
line = find_pcd_header_entry(fid, 'VIEWPOINT');
lineTmp = textscan(line, '%s');
pcd.header.viewpoint = str2double(lineTmp{1}(2:end));

% Number of points
line = find_pcd_header_entry(fid, 'POINTS');
pcd.header.points = sscanf(line, 'POINTS %d');

% Get data type
line = find_pcd_header_entry(fid, 'DATA');
pcd.header.data = sscanf(line, 'DATA %s');

% Header Size
pcd.header.headerSize = ftell(fid);

% Close the PCD file
fclose(fid);
end

function pcd = get_matlab_type(pcd)
raiseError = false;
type = 'N';
size = 0;

typeChar = pcd.header.type;
sizeAll = pcd.header.size;
typeCount = numel(typeChar);
matlabType = cell(typeCount, 1);

if typeCount ~= numel(sizeAll)
    error('ERROR: SIZE and TYPE have unequal size. Invalid PCD format.')
end

for i = 1:typeCount
    
    type = typeChar(i);
    size = sizeAll(i);
    
    if strcmp(type, 'I')
        switch size
            case 1
                matlabType{i} = 'int8';
            case 2
                matlabType{i} = 'int16';
            case 4
                matlabType{i} = 'int32';
            case 8
                matlabType{i} = 'int64';
            otherwise
                raiseError = true; break;
        end
    elseif strcmp(type, 'U')
        switch size
            case 1
                matlabType{i} = 'uint8';
            case 2
                matlabType{i} = 'uint16';
            case 4
                matlabType{i} = 'uint32';
            case 8
                matlabType{i} = 'uint64';
            otherwise
                raiseError = true; break;
        end
    elseif strcmp(type, 'F')
        switch size
            case 4
                matlabType{i} = 'single';
            case 8
                matlabType{i} = 'double';
            otherwise
                raiseError = true; break;
        end
    else
        raiseError = true; break;
    end
end

if raiseError
    error('ERROR: Type %s and Size %d is not a valid combination. Invalid PCD format.', type, size);
end

pcd.header.matlab_type = matlabType;
end

function formatSpec = get_formatSpec(typeChar)

if strcmp(typeChar, 'I')
    formatSpec = '%d';
elseif strcmp(typeChar, 'U')
    formatSpec = '%u';
elseif strcmp(typeChar, 'F')
    formatSpec = '%f';
else
    error('ERROR: Type %s is invalid. Invalid PCD format.', typeChar);
end
end

function pcd = createDataFields(pcd)

for i = 1:numel(pcd.header.fields)
    pcd.(pcd.header.fields{i}) = [];
end
end