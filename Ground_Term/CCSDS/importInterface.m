function allData = importInterface(filename)
%
%   importInterface(filename)
%       imports a header file and writes a matlab files to initalize the
%       #defines as variables
%
%   Steve Lentine
%   4/20/16
%

    % check the filename argument to make sure its a string
    if(~ischar(filename))
        error('importInterface:FilenameString','Filename argument should be a string');
    end

    % read the lines of the input file into a cell array
    fid = fopen(filename);
    allData = textscan(fid,'%s','Delimiter','\n');
    fclose(fid);

    % define the output filename
    out_filename = 'out_interface.m';
    
    % open the output file
    outfile = fopen(out_filename,'w');
    
    for i = 1:length(allData{1})
       pattern = '^\s*#define\s*(.*?)\s+([x0-9A-Fa-f]*)\s*';
       rtn = regexp(allData{1}{i},pattern,'tokens');
       % if a match was found
       if(~isempty(rtn))
           % is the variable name isn't empty
           if(~isempty(rtn{1}{1}))
               % if its hex, convert it to decimal
               if(~isempty(strfind(rtn{1}{2},'0x')))
                    fprintf(outfile,'%s = hex2dec(''%s''); \n',rtn{1}{1},rtn{1}{2});
               % otherwise just output the number
               else
                    fprintf(outfile,'%s = %s; \n',rtn{1}{1},rtn{1}{2});
               end
           end
       end
    end
    
    % close the output file
    fclose(outfile);
end