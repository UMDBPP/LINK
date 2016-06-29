function setupPath()
% recursively adds all folders below this script to the matlab path
%
%   setupPath()
%       recursively adds all folders below this script to the matlab path
%
% sets up the path for the telemetry database. Adds all folders adjacent to
% the directory this script resides in to the path

    % get a recursive list of all child folders, add to path
    addpath(genpath(fileparts(mfilename('fullpath'))));

end