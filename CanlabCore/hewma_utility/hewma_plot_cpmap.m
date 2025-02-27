function [cl2,classes] = hewma_plot_cpmap(varargin)
% Visualize a change_point map stored in hewma_cp.img
% (output from hewma2)
% and classify voxels into groupings based on CP
%
% :Usage:
% ::
%
%     [cl2,classes] = hewma_plot_cpmap
%

name = 'hewma_cp.img';
%name = 'hewma_runlen.img';

if length(varargin) > 0, name = varargin{1};,end

% ----------------------------------------------------
% initial viewing of CP map
% ----------------------------------------------------

cl = mask2clusters(name);

cluster_orthviews(cl);


% ----------------------------------------------------
% load data
% ----------------------------------------------------

v = spm_read_vols(spm_vol(name));
v2 = v(:); v2 = round(v2);
v2(abs(v) < eps | isnan(v)) = [];


% ----------------------------------------------------
% make histogram and get clusters (classifications) of CPs
% ----------------------------------------------------

nbins = unique(v2);
tor_fig; f1 = gcf; [h,x] = hist(v2,nbins); hh = bar(x,h); set(hh,'FaceColor',[.5 .5 .5])

nclasses = input('How many classes?');

err = 1; indx = 1;
while err
    try
        classes = kmeans(v2, nclasses);   % ,'start','uniform');
        err = 0;
    catch
    end
    indx = indx + 1;
    if indx == 11, disp('kmeans: tried 10 times.  No solution.'); err = 0;, return, end
end


maxcp = max(v2);
for i = 1:maxcp, tmp = unique(classes(find(v2==i))); 
    if isempty(tmp), classmap(i) = 0;, 
    else,classmap(i) = tmp(1);, end
end

CLU = clusters2CLU(cl);
CLU.Z = round(CLU.Z); CLU.Z(abs(CLU.Z)<eps) = NaN;
CLU.Z = classmap(CLU.Z);
CLU.cp = v2';


% ----------------------------------------------------
% define colors and sort by class size
% ----------------------------------------------------

%colors = {[1 0 0] [0 1 0] [0 0 1] [1 1 0] [1 0 1] [0 1 1]};
%while length(colors) < nclasses, colors = [colors colors];,end

colors = hot(nclasses+2);
for i = 1:length(colors) - 1, col{i} = colors(i,:);,end
colors = col(2:end);    %(floor(length(col)./3):end);

% sort by change point, ascending
for i = 1:nclasses, 
    meancp(i) = mean(v2(classes==i));,
    nvox(i) = sum(classes==i);
    indx(i) = i;
end
[meancp,i] = sort(meancp,2,'ascend');
%nvox(i) = nvox(1:length(i));
%indx(i) = indx(1:length(i));
nvox  = nvox(i);
indx = indx(i);

%table
fprintf(1,'\nClass\tNum. Voxels\tMean CP\tColor\t\t\n');
for j =1:nclasses
    fprintf(1,'%3.0f\t%3.0f\t%3.2f\t%3.2f\t%3.2f\t%3.2f\t\n',indx(j),nvox(j),meancp(j),colors{j}(1),colors{j}(2),colors{j}(3));
end
fprintf(1,'\n');

% sort by class size
%for i = 1:nclasses, nvox(i) = sum(classes==i);,end
%[nvox,i] = sort(nvox,2,'descend');

%colors(i) = colors(1:length(i));


% ----------------------------------------------------
% re-plot histogram with color codes
% ----------------------------------------------------
figure(f1);
for i = 1:nclasses
    wh = find(classmap == indx(i)); range = [min(wh) max(wh)]; 
    wh = find(x <= range(2) & x >= range(1));
    hh = bar(x(wh),h(wh)); set(hh,'FaceColor',colors{i});
end
xlabel('Change point')
ylabel('Number of voxels')


% ----------------------------------------------------
% re-make separate clusters for each class
% and plot on brain
% ----------------------------------------------------

clear cl2 
for i = 1:nclasses
    CLUtmp = CLU;  
    wh = find(CLUtmp.Z == indx(i));
    CLUtmp.XYZmm = CLUtmp.XYZmm(:,wh);
    CLUtmp.XYZ = CLUtmp.XYZ(:,wh);
    CLUtmp.Z = CLUtmp.Z(:,wh);
    CLUtmp.cp = CLUtmp.cp(:,wh);
    cl2{i} = tor_extract_rois([],CLUtmp,CLUtmp);
    
    if i == 1
        cluster_orthviews(cl2{i},colors(i));
    else
        cluster_orthviews(cl2{i},colors(i),'add');
    end
end


%cmap = colormap(lines);





% -------------------------------------------------------------------
% * timeseries plotting
% -------------------------------------------------------------------
        
go = input('Plot timeseries?');

if go
    if ~(exist('EXPT') == 1)
        file = spm_get(1,'*mat','Select EXPT.mat',pwd);
        [dd,ff,ee] = fileparts(file);
        cd(dd)
        load(file)
    end
    
    % used in button-up fcn callback
    E2 = EXPT;
    clear EXPT

    cl = cl2;
    
    global VOL
    global f
    global f2
    global EXPT
    EXPT = E2;


    set(gcf,'WindowButtonUpFcn','[dat,files,stats,mycov] = hewma_plot_coord_btnupfcn;')

    % get coordinate mapping matrix
    VOL = struct('M',cl{1}(1).M);

    % prepare figure
    f1 = figure('Color','w','Name','Hewma plots');
    f = f1;     % button callback uses figure f


    stop = input('Click on figure to plot.  Press return to exit.');
    
end


return



