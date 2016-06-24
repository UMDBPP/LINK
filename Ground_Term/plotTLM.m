function plotTLM(var_str)

    % ensure that field exists
    if(~evalin('base',sprintf('isfield(TLM,''%s'')',var_str)))
        error('plotTLM:VarDoesntExist','Field ''%s'' doesn''t exist in telemetry database',var_str)
    end

    % get telemetry from workspace
    TLM_DB = evalin('base','TLM');
    
    % create the figure
    hdl = figure('Name',sprintf('%s liveplot',var_str));
    
    % plot the data, linking the plot to the data in the base workspace
    h = plot(TLM_DB.(var_str),'XDataSource',sprintf('TLM.%s.time',var_str),'YDataSource',sprintf('TLM.%s.data',var_str));
    
    % plot with dates on x axis
    datetick('x', 'HH:MM');

    % add grid
    grid on
    
    % turn on the linking
    linkdata(hdl)
set(gca,'XTickMode','auto')
end