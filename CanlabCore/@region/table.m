function [poscl, negcl, results_table] = table(cl, varargin)
% Print a table of all regions in a region object (cl). Return labeled
% clusters (separated by those with positive and negative peak values) and
% a Matlab table object with the relevant information.
%
% :Usage:
% ::
%
%    [poscl, negcl] = table(cl, [optional inputs])
%
% :Optional inputs:
%
%   **k:**
%        Print only regions with k or more contiguous voxels
%
%   **nosep:**
%        do not separate cl with pos and neg effects based on peak in .val
%
%   **names:**
%        name clusters manually before printing to table and output; saves in .shorttitle field
%
%   **forcenames:**
%        force manual naming of cl by removing existing names in .shorttitle field
%
% :Outputs:
%
%   Returns region objects for cl with pos and neg effects
%   - autolabeled if Neuroimaging_Pattern_Masks and atlas tools are available on Matlab path
%   - limited by size if entered
%   - manually named if requested (see optional inputs)
%
% ..
%     Author and copyright information:
%
%     Copyright (C) 2011  Tor Wager
%
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>.
% ..
% :Examples:
% -------------------------------------------------------------------------
% ::
% Example 1:
% % Complete group analysis of a standard dataset
% % Do analysis and prep results region object:
%
%   img_obj = load_image_set('emotionreg');         % Load a dataset
%   t = ttest(img_obj, .005, 'unc');                % Do a group t-test
%   t = threshold(t, .005, 'unc', 'k', 10);         % Re-threshold with extent threshold of 10 contiguous voxels
%   r = region(t);                                  % Turn t-map into a region object with one element per contig region
%
%   Label regions and print a table:
%   [r, region_table, table_legend_text] = autolabel_regions_using_atlas(r);  
%                                                   % Label regions. Can be skipped because 'table' below attempts to do this automatically
%   table(r);                                       % Print a table of results using new region names
%
%   [rpos, rneg] = table(r);                        % Print and table and return region object separated into regions with positive vs. negative statistic values (from .Z field)

% ..
%    Programmers' notes:
%    List dates and changes here, and author of changes
% ..
%    July 2018:  Autolabel update and "new 2018 version", Tor Wager. Also added legend text.


n_cols = 140;                       % 140 good for HTML reports
sep_str = repmat('_', 1, n_cols);   % see textwrap

k = 0;
dosep = true;
donames = false;        % name clusters before printing to table and output; saves in .shorttitle field (legacy only)
forcenames = false;     % force naming of cl by removing existing names in .shorttitle field (legacy only)
dolegacy = false;
dosortrows = true;          % sort rows by area

for i = 1:length(varargin)
    if ischar(varargin{i})
        switch varargin{i}
            
            % functional commands
            case {'k', 'maxsize'}, k = varargin{i+1};
            case 'nosep', dosep = 0;
            case {'names', 'name', 'donames'}, donames = true;
            case 'forcenames', forcenames = true;
                
            case {'nosort', 'nosortrows'}, dosortrows = false;
                
            case {'legacy', 'dolegacy'}, dolegacy = true;
                
            otherwise, warning(['Unknown input string option:' varargin{i}]);
        end
    end
end

% Trim by number of contiguous voxels if requested
% -------------------------------------------------------------------------

if k
    cl(cat(1, cl.numVox) < k) = [];
end

% Separate subregions with positive and negative values if requested
% -------------------------------------------------------------------------
if dosep
    % separate pos and neg
    [poscl, negcl] = posneg_separate(cl);
    
    cl = [poscl negcl];
    ispos = [true(1, length(poscl)) false(1, length(negcl))]; % logical for splitting combined cl later
    
    clear poscl negcl
    
    fprintf('\n%s\nPositive Effects\n', sep_str)
else
    %     % just return cl in poscl
    %     poscl = cl;
    %     negcl = [];
    fprintf('\n%s\nTable of all regions\n', sep_str)
end


% Attempt to label regions with descriptive names; requires
% Neuroimaging_Pattern_Masks repository
% Used in both legacy and 2018+ version
% If empty, skips and returns empty table vars.
% Must do after separating pos and neg clusters because some regions may be split.
% -------------------------------------------------------------------------

% do this with concatenated pos and neg cl because it's faster.
[cl, region_table, table_legend_text, dolegacy] = autolabel_regions(cl, dolegacy);


% Manual labeling of names
% -------------------------------------------------------------------------

if donames
    
    if forcenames
        for i = 1:length(cl)
            cl(i).shorttitle = [];
        end
    end
    
    cl = cluster_names(cl);
end


% separate again so we return clusters with region names added.

if dosep
    % re-separate for output
    if any(ispos)
        poscl = cl(ispos);
    else
        poscl = [];
    end
    
    if any(~ispos)
        negcl = cl(~ispos);
    else
        negcl = [];
    end
    
else
    % not separating
    poscl = cl;
    negcl = [];
end

% poscl and negcl are done here, so we have values to be returned.
% the code below uses overall cl and prints the table.

% Legacy table
% - uses cluster_table
% -------------------------------------------------------------------------
if dolegacy
    print_legacy_table(cl, ispos, table_legend_text);
    
elseif isempty(region_table)
    
    disp('No regions to display');
    
    fprintf('\nNegative Effects\n')
    
    disp('No regions to display');
    
    disp(sep_str);
    
    return
    
else
    % build table we want in table format and rename. Reformat a bit.
    % note for beta testing: table will break if regions are missing from
    % region_table.
    
    %T2 = movevars(T1, VARS, 'Before', LOCATION)
    
    % Good idea, but Matlab 2018a does not move descriptions with moves anyway
    %     results_table = region_table;
    %     results_table = movevars(results_table, 'modal_label', 'Before', 1);
    %     results_table = removevars(results_table, 'Region');
    %     results_table = removevars(results_table, 'Voxels');
    
    Region = table(region_table.modal_label, 'VariableNames', {'Region'});
    Volume = table(region_table.Region_Vol_mm, 'VariableNames', {'Volume'});
    Atlas_coverage = region_table(:, [6 7 4]);
    XYZ = table(round(cat(1, cl.mm_center)), 'VariableNames', {'XYZ'});
    
    % Z = get_max_Z(cl);
    Z = get_signed_max(cl, 'Z', 'maxZ');  % use function because may be empty, handle if so
    
    results_table = [Region Volume XYZ Z Atlas_coverage];
    results_table.region_index = (1:size(region_table, 1))';
    
    results_table_pos = results_table(ispos, :);
    results_table_neg = results_table(~ispos, :);
    
    % Sort, if asked for (default = yes)
    if dosortrows
    
        % Replace empty strings so sort will work
        whempty = cellfun(@isempty, results_table_pos.modal_label_descriptions);
        results_table_pos.modal_label_descriptions(whempty) = {'X_No_label'};
        
        whempty = cellfun(@isempty, results_table_neg.modal_label_descriptions);
        results_table_neg.modal_label_descriptions(whempty) = {'X_No_label'};
        
        results_table_pos = sortrows(results_table_pos, 'modal_label_descriptions');
        results_table_neg = sortrows(results_table_neg, 'modal_label_descriptions');
        
        % Manual - not as good because Matlab's table methods handle this well.
        %             % Replace empty and get unique labels to sort by
        %             whempty = cellfun(@isempty, results_table_pos.modal_label_descriptions);
        %             results_table_pos.modal_label_descriptions(whempty) = {'No_label'};
        %             u = unique(results_table_pos.modal_label_descriptions);
        % 
        %             [~, ~, condf] = string2indicator(results_table_pos.modal_label_descriptions)
        % 

    end
    
    
    % Now split into positive and neg sub-tables and display
    
    if any(ispos)
        disp(results_table_pos)
    else
        disp('No regions to display');
    end
    
    fprintf('\nNegative Effects\n')
    if any(~ispos)
        disp(results_table_neg)
    else
        disp('No regions to display');
    end
    
end

if isempty(table_legend_text)
    return
end

% clean up text
if length(table_legend_text) > 2
    table_legend_text(2:3) = [];
end

table_legend_text = strrep(table_legend_text, 'Modal_label', 'Region');
table_legend_text = strrep(table_legend_text, 'Region_Vol_mm', 'Volume');

if isempty(cl(1).Z_descrip)
    myzdescrip = 'MaxZ: Unknown quantity; label in .Z_descrip field in region object.';
    
else
    myzdescrip = ['MaxZ: Signed max over ' cl(1).Z_descrip];

end

table_legend_text = [table_legend_text(1:2) myzdescrip table_legend_text(3:end)];

table_legend_text(end+1) = {'\nNote: Region object r(i).title contains full list of reference atlas regions covered by each cluster.'};

% print
canlab_print_legend_text(table_legend_text{:});


end % main function



function print_legacy_table(cl, ispos, table_legend_text)

if any(ispos)
    cluster_table(cl(ispos), 0, 0);
else
    disp('No regions to display');
end

fprintf('\nNegative Effects\n')

if any(~ispos)
    cluster_table(cl(~ispos), 0, 0);
else
    disp('No regions to display');
end

% canlab_print_legend_text(table_legend_text'); % could use disp() here, but canlab function is more flexible

end % function



function val_table = get_signed_max(cl, myfield, tablevarname)
% Returns a table with var "MaxZ" nregions x 1, or empty if cl.Z is empty

%maxZ = @(i) max(double(cl(i).Z));

smax = @(i) signedmax(cl(i).(myfield));

for i = 1:length(cl)
    
    if ~isempty(cl(i).(myfield))
        myZ(i, 1) = smax(i);
    else
        myZ(i, 1) = NaN;
    end
    
    %if isinf(smax(i)), keyboard, end
    
end

% Fix infinite vals - only for .Z . so this is not generalizable beyond
% this function without modifications:
maxZ = norminv(1 - 1E-12);
myZ(myZ > maxZ) = maxZ;

if all(isnan(myZ))
    val_table = [];
else
    val_table = table(myZ,  'VariableNames', {tablevarname});
end

end % function

function val = signedmax(vals)

vals = double(vals);
[maxabs, wh] = max(abs(vals));

val = sign(vals(wh)) .* maxabs;

end


function [cl, region_table, table_legend_text, dolegacy] = autolabel_regions(cl, dolegacy)

table_legend_text = '';
region_table = [];

if isempty(cl)
    region_table = [];
    return
end

try
    [cl, region_table, table_legend_text] = autolabel_regions_using_atlas(cl);
    
    % A bit of error checking to make sure things don't break in beta
    % testing...
    if size(region_table, 1) ~= length(cl)
        disp('Error - region table and region obj do not match. Debug code.')
        disp('Reverting to ''legacy'' table');
        dolegacy = true;
    end
    
    % Add description of all regions to legend
catch
    
    disp('Region autolabel did not work; add Neuroimaging_Pattern_Masks repository (see canlab_toolbox_setup.m)');
    dolegacy = true;
    
end

end % function