function run_read_write_test()
%run_read_write_test() reads and writes files in example_data to test functionality
%   Test checks if read and written pcd file contents are equal.
%   Test throws exception on read or write error.

upper_dir = fileparts(fileparts(mfilename("fullpath")));
addpath(upper_dir);

test_suffix   = '_tested';
sample_folder = fullfile(upper_dir, 'example_data');
test_files    = dir(fullfile(sample_folder, '*.pcd'));
test_files    = test_files(cellfun(@(x) isempty(strfind(x,test_suffix)), {test_files.name})); %#ok

errorCount = 0;
for iFile = 1:length(test_files)
    
    fprintf('----\n');
    file_in = fullfile(test_files(iFile).folder, test_files(iFile).name);
    [~, filename, fileext] = fileparts(file_in);
    file_out = fullfile(sample_folder, strcat(filename, test_suffix, fileext));
    
    fprintf('Testing File: %s ...\n', file_in);
    pcd_in      = readPCDfile(file_in);
    
    fprintf('Write File: %s ...\n', file_out);
    pcd_out     = writePCDfile(pcd_in, file_out);
    pcd_compare = readPCDfile(file_out); 
    
    fprintf('Comparing pcd struct before and after write ...\n');
    if ~isequal(pcd_in, pcd_out)
        fprintf('   Failure: NOT Equal! Writer rearranges input. This might NOT be an error!\n');
        errorCount = errorCount + 1;
    else
        fprintf('   Success: Structs are Equal!\n');
    end
    
    fprintf('Comparing test file and reread output file ...\n');
    contents_equal = true;
    
    % Compare header structure and data contents
    current_field = ' ';
    fields        = fieldnames(pcd_in);
    for iField = 1:numel(fields)
        
        current_field      = fields{iField};
        current_field_data = pcd_in.(current_field);
        
        if isstruct(current_field_data)
            sub_fields     = fieldnames(current_field_data);
            
            for iSubField = 1:numel(fields)
                sub_field = sub_fields{iSubField};
                if ~isequal(current_field_data.(sub_field), pcd_compare.(current_field).(sub_field))
                    contents_equal = false;
                    break;
                end
            end
            
        elseif ~isequal(current_field_data, pcd_compare.(current_field))
            contents_equal = false;
            break;
        end
    end
    
    if ~contents_equal
        fprintf('   Failure: NOT Equal! Reader and Writer return different data in field %s!!!\n', current_field);
        errorCount = errorCount + 1;
    else
        fprintf('   Success: Reader and Writer return same data\n');
    end
    
end
fprintf('----\n');

state = 'Success';
if (errorCount > 0)
    state = 'Failure';
end
fprintf('%s: Test finished with %d errors!\n', state, errorCount);

end

