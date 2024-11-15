function validVarName = MakeValidVariableName(varName)
% validVarName = MakeValidVariableName(varName)
%   Turns the argument varName into a valid matlab variable
%   name and returns this new name. Every invalid character
%   will be turned into an underscore. If name starts with
%   a number or underscore then the letter 'v' (for variable)
%   will be put in front
%
%   Matlab has the capability to do the same but only from
%   version 2014a onwards

if iscell(varName) || ~ischar(varName)
    error('Input must be a char array')
end

inputSize = size(varName);
if min(inputSize) ~= 1
    error('Input can not be 2D char array')
end

% If input is already valid then return the input after
% removing trailing zeros
validVarName = strcat(varName);
if isvarname(validVarName)
    return;
end

% If max amount of characters exceeded then shorten it
if max(inputSize) >  namelengthmax
    validVarName = validVarName(1:namelengthmax-1);
end

% Replace every non letter, non underscore and non number
% with underscores
name_as_uint8 = uint8(validVarName);
charIsNumber     = name_as_uint8 > 47 & name_as_uint8 < 58;
charIsUnderscore = name_as_uint8 == 95;
invalidChars = ~((name_as_uint8 > 96 & name_as_uint8 < 123) |...
    (name_as_uint8 > 64 & name_as_uint8 <  91) |...
    charIsUnderscore | charIsNumber);
name_as_uint8(invalidChars) = 95;

% If name starts with number or underscore then add 'v' in front
if charIsNumber(1) || charIsUnderscore(1)
    name_as_uint8 = horzcat(118,name_as_uint8);
end

% Convert back to chars
validVarName = char(name_as_uint8);

end