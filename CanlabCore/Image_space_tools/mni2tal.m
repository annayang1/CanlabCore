function outpoints = mni2tal(inpoints)
% Converts coordinates from MNI brain to best guess
% for equivalent Talairach coordinates
%
% :Usage:
% ::
%
%     outpoints = mni2tal(inpoints)
%
% Where inpoints is N by 3 or 3 by N matrix of coordinates
% (N being the number of points)
%
% :Output:
%
%   **outpoints:**
%        is the coordinate matrix with Talairach points
%
% ..
%    Matthew Brett 10/8/99
% ..

dimdim = find(size(inpoints) == 3);
if isempty(dimdim)
  error('input must be a N by 3 or 3 by N matrix')
end
if dimdim == 2
  inpoints = inpoints';
end

% Transformation matrices, different zooms above/below AC
upT = spm_matrix([0 0 0 0.05 0 0 0.99 0.97 0.92]);
downT = spm_matrix([0 0 0 0.05 0 0 0.99 0.97 0.84]);

tmp = inpoints(3,:)<0;  % 1 if below AC
inpoints = [inpoints; ones(1, size(inpoints, 2))];
inpoints(:, tmp) = downT * inpoints(:, tmp);
inpoints(:, ~tmp) = upT * inpoints(:, ~tmp);
outpoints = inpoints(1:3, :);
if dimdim == 2
  outpoints = outpoints';
end




