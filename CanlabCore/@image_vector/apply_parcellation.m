function [parcel_means, parcel_pattern_expression, parcel_valence] = apply_parcellation(dat, parcels, varargin)
% Computes the mean value / pattern expression for each parcels specified in a data object
%
% Usage:
% ::
%
%    [parcel_means, parcel_pattern_expression, parcel_valence] = apply_parcellation(dat,parcels,'pattern_expression',fmri_data('pattern.nii'))
%
% This is a method for an fmri_data object that computes the mean value and
% optionally, pattern expression within parcels. This can be used to
% compare the average activity within a region to the expression of a
% particular marker
%
% ..
%     Author and copyright information:
%
%     Copyright (C) 2017 Phil Kragel
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
%
% :Inputs:
%
%   **dat:**
%       fmri_data object with data to analyze
%
%   **parcels:**
%        fmri_data object with parcellation image, with parcel ID coded
%        with unique integer values in the image
%        This can (and ideally is) an atlas object type.
%        Atlas objects handle resampling integer vectors better, so use atlas object if available
%
% :Optional Inputs:
%
%   **pattern_expression:**
%       followed by an fmri_data object with multivariate pattern to apply.
%       local patterns in each parcel are applied, and pattern responses
%       returned for each parcel.
%
%   **correlation:**
%        calculate the pearson correlation coefficient of each
%        image in dat and the values in the mask.
%
%   **norm_mask:**
%        normalize the mask weights by L2 norm
%
%   **ignore_missing:**
%        used with pattern expression only. Ignore weights on voxels
%        with zero values in test image. If this is not entered, the function will
%        check for these values and give a warning.
%
%   **cosine_similarity:**
%        used with pattern expression only. scales expression by product of
%        l2 norms (norm(mask)*norm(dat))
%
% :Outputs:
%
%   **parcel_means:**
%       Matrix of mean data values for each parcel, data images x parcels
%       This will always be the parcel means, even if pattern expression is
%       requested. Pattern expression will be returned in a separate
%       output.
%
%   **parcel_pattern_expression:**
%        If 'pattern_expression' is entered followed by a linear
%        multivariate pattern object, parcel_pattern_expression returns the 
%        local expression (dot product) of the pattern for each data image
%        (row), in each parcel region (column)
%
%   **parcel_valence:**
%        Define pattern valence as similarity with unit vector (all positive,
%        identical weights)
%
%        If x is a vector of pattern weights,
%        The cosine similarity with the unit vector is a measure of how uniform
%        the weights are, on a scale of 1 to -1.  1 indicates that the pattern
%        computes the region average (all weights identical and positive). -1
%        indicates that the pattern computes the negative region average (all
%        weights identical and negative).
%
%
% :Examples:
% ::
%
% % Load the Shen 2013 NIMG parcellation and a sample dataset, and get the
%   means for each parcel in each image in the dataset.
%
%     parcel_image = which('shen_2mm_268_parcellation.nii');
%     parcel_obj = atlas(parcel_image, 'noverbose');
%     dat = load_image_set('emotionreg');
%     parcel_means = apply_parcellation(dat, parcel_obj);
%
% % Calculate the local NPS pattern response in each region within the Shen
% % atlas. This requires the (Private) pattern images containing the NPS map to be on your path!
%    nps = load_image_set('npsplus');
%    nps = get_wh_image(nps, 1);
%    [parcel_means, local_pattern_response] = apply_parcellation(dat, parcel_obj, 'pattern_expression', nps);
%
%    Parcels without pattern values will be NaN.  Visualize in-pattern
%    parcels:
%    r = region(parcel_obj, 'unique_mask_values');
%    wh_parcels = ~all(isnan(parcel_means));
%    orthviews(r(wh_parcels));
%
% :See also:
% image_vector.extract_roi_averages, fmri_data.extract_roi_averages
%
% ..
%    Notes:
%    Created: 5/12/17 Phil Kragel - bits of code taken from apply_mask
%             5/13/17 Phil and Tor revise; minor edits by Tor Wager
%             2/5/18  Tor added support for atlas object, pattern valence
%             8/18    Tor adjusted condf2indic to avoid bug with empty parcels at end of list returning wrong size output
% ..

[parcel_means, parcel_pattern_expression, parcel_valence] = deal([]);

dopatternexpression = 0;

if isa(parcels, 'atlas')
    
    parcels.probability_maps = []; % speed up resampling dramatically. not needed here.
    
end

% Check parcels
% Get integer vector of unique parcel IDs, before any resampling.
% -------------------------------------------------------------------------
if size(parcels.dat, 2) > 1
    error('Sorry, this function currently only works for one parcel image at a time!')
end

% u = unique(double(parcels.dat));
% u(u == 0) = [];
% if ~all(u == round(u))
%     warning('Some parcel values are not integers.');
% end

% get pattern_image data object if specified
% -------------------------------------------------------------------------

if any(strcmp(varargin, 'pattern_expression'))
    
    pattern_image = varargin{find(strcmp(varargin, 'pattern_expression')) + 1};
    dopatternexpression = true;
    
    % resample pattern_image to data space
    [dat, pattern_image] = match_spaces(dat, pattern_image);
    
    if size(pattern_image.dat, 2) > 1
        error('Sorry, this function currently only works for one pattern at a time!')
    end
    
end

% Resample parcels to data space
% -------------------------------------------------------------------------

% save num of original parcels, to make sure matrix contains a column for each original parcel
if isa(parcels, 'atlas')
    n_orig_parcels = num_regions(parcels);
else
    n_orig_parcels = max(parcels.dat);  % fmri_data. max, not length(unique), because if there are missing integers we want empty cols for these
end

[dat,parcels] = match_spaces(dat, parcels);  % keeps only in-image parcels


% Get indicator vectors from integers in parcels.dat
% -------------------------------------------------------------------------

parcels.dat = condf2indic(parcels.dat, 'integers', n_orig_parcels);

% 
% % Turn integer vector into 1s and 0s - matrix of binary masks
% % some may be missing after resampling
% 
% parcels = remove_empty(parcels);
% [parcels.dat, parcels_we_have] = condf2indic(parcels.dat);
% 
% % if codes are 1...n, parcels_we_have is index values...but if there are
% % missing integers, need to re-map them into indices
% index_values = 1:length(u);
% [~, wh] = intersect(u, parcels_we_have);
% index_values = index_values(wh);
% 
% % Insert NaNs for any missing parcels.  Happens rarely, but could happen.
% missing_parcels = true(size(u));
% missing_parcels(index_values) = false;
% 
% parcels.dat = naninsert(missing_parcels, parcels.dat')';
% 

%for computing means, scale each column of parcels to sum to 1
parcels.dat = bsxfun(@rdivide, parcels.dat, nansum(parcels.dat));

%matrix products will give us the mean now...
parcel_means = dat.dat' * parcels.dat;


% Parcel valence
% -------------------------------------------------------------------------

parcel_valence = NaN * ones(size(parcel_means));

% voxel counts in each parcel
% nvox_by_parcel = sum(parcels.dat ~= 0 & ~isnan(parcels.dat))';

% Get cosine similarity of each data image with unit vector within each parcel
% cosine_sim = @(x, y) (x'* y) / (norm(x) .* norm(y));

% % for similarity with unit vector: Simplifies to:
% n = length(x);
% cosine_sim_with_unit = @(x) sum(x) ./ sqrt(x' * x * n);
% vector version:
cosine_sim_with_unit = @(x) (sum(x)') ./ sqrt(diag(x' * x) .* size(x, 1));

for i = 1:size(parcels.dat, 2)
    
    % skip if this parcel is empty
    if all(isnan(parcel_means(:, i)))
        continue
    end
    
    x = double(dat.dat(parcels.dat(:, i) ~= 0, :));
    pv = cosine_sim_with_unit(x);
    
    parcel_valence(:, i) = pv;
    
end % parcel_valence


% Pattern expression
% -------------------------------------------------------------------------

if dopatternexpression
    
    %go back to binary values for parcels
    parcels.dat = single(parcels.dat > 0);
    
    parcels = replace_empty(parcels);
    pattern_image = replace_empty(pattern_image);
    
    %expanded_mask = mask.dat; % would do for full set all at once, no
    %loop...debug
    
    %expand pattern_image.dat to provide output for each parcel
    parcel_pattern_expression = NaN .* zeros(size(parcel_means));
    
    % Create matrix mask_by_parcels, in which each column is a local pattern within a parcel
    % ---------------------------------------------------------------------
    % Init 
    mask_by_parcels = nan(size(pattern_image.dat, 1), size(parcels.dat, 2));
    
    % Expand into series of patterns
    for i = 1:size(parcels.dat, 2)
        
        % skip if this parcel is empty
        if all(isnan(parcel_means(:, i)))
            continue
        end
        
        mask_by_parcels(:, i) = pattern_image.dat(:, 1) .* parcels.dat(:, i); % zero out-of-parcel voxels
        
    end
    
    % Pass similarity metric in to canlab_pattern_similarity
    dat = replace_empty(dat);
    parcel_pattern_expression = canlab_pattern_similarity(dat.dat, mask_by_parcels, 'ignore_missing', varargin{:});
    
    %tried doing this all at once, but apply_mask has issues where it
    %excludes voxels (it also loops over patterns as well when it calls
    %canlab_pattern_similarity - so not any slower to do this loop here)
    
end % Pattern expression



end  % Main function



function [dat,parcels] = match_spaces(dat,parcels)
%code taken from apply_mask to make sure data are in same space


isdiff = compare_space(dat, parcels);

if isdiff == 1 || isdiff == 2 % diff space, not just diff voxels
    
    % Both work, but resample_space does not require going back to original
    % images on disk.
    %mask = resample_to_image_space(mask, dat);
    
    % Atlas objects handle resampling better, so use atlas object if available
    % Same method resample_space, with support for atlas
    
    parcels = resample_space(parcels, dat, 'nearest');
    
    if length(parcels.removed_voxels) == parcels.volInfo.nvox
        disp('Warning: resample_space returned illegal length for removed voxels. Fixing...');
        parcels.removed_voxels = parcels.removed_voxels(parcels.volInfo.wh_inmask);
    end
    
end

dat = remove_empty(dat);
nonemptydat = ~dat.removed_voxels; % remove these

dat = replace_empty(dat);

% Check/remove NaNs. This could be done in-object...
parcels.dat(isnan(parcels.dat)) = 0;

% Replace if necessary
parcels = replace_empty(parcels);


% save which are in mask, but do not replace with logical, because mask may
% have weights we want to preserve
inparcelsdat = logical(parcels.dat);


% Remove out-of-mask voxels
% ---------------------------------------------------

% mask.dat has full list of voxels
% need vox in both mask and original data mask

if size(parcels.volInfo.image_indx, 1) == size(dat.volInfo.image_indx, 1)
    n = size(parcels.volInfo.image_indx, 1);
    
    if size(nonemptydat, 1) ~= n % should be all vox OR non-empty vox
        nonemptydat = zeroinsert(~dat.volInfo.image_indx, nonemptydat);
    end
    
    if size(inparcelsdat, 1) ~= n
        inparcelsdat = zeroinsert(~parcels.volInfo.image_indx, inparcelsdat);
    end
    
    inboth = inparcelsdat & nonemptydat;
    
    % List in space of in-mask voxels in dat object.
    % Remove these from the dat object
    to_remove = ~inboth(dat.volInfo.wh_inmask);
    
    to_remove_parcels = ~inboth(parcels.volInfo.wh_inmask);
    
elseif size(parcels.dat, 1) == size(dat.volInfo.image_indx, 1)
    
    % mask vox are same as total image vox
    nonemptydat = zeroinsert(~dat.volInfo.image_indx, nonemptydat);
    inboth = inparcelsdat & dat.volInfo.image_indx & nonemptydat;
    
    % List in space of in-mask voxels in dat object.
    to_remove = ~inboth(dat.volInfo.wh_inmask);
    
    to_remove_parcels = ~inboth(parcels.volInfo.wh_inmask);
    
elseif size(parcels.dat, 1) == size(dat.volInfo.wh_inmask, 1)
    % mask vox are same as in-mask voxels in dat
    inboth = inparcelsdat & dat.volInfo.image_indx(dat.volInfo.wh_inmask) & nonemptydat;
    
    % List in space of in-mask voxels in .dat field.
    to_remove = ~inboth;
    
    to_remove_parcels = ~inboth;
    
else
    fprintf('Sizes do not match!  Likely bug in match_spaces.\n')
    fprintf('Vox in mask: %3.0f\n', size(mask.dat, 1))
    fprintf('Vox in dat - image volume: %3.0f\n', size(dat.volInfo.image_indx, 1));
    fprintf('Vox in dat - image in-mask area: %3.0f\n', size(dat.volInfo.wh_inmask, 1));
    disp('Stopping to debug');
    keyboard
end

dat = remove_empty(dat, to_remove);
parcels = remove_empty(parcels, to_remove_parcels);

end % match_spaces
