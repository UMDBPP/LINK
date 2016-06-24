function setupPath()
% sets up the path for the telemetry database. Adds all folders adjacent to
% the directory this script resides in to the path

    addpath(genpath(fileparts(mfilename('fullpath'))));

end