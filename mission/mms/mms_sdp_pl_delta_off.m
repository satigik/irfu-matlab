function res = mms_sdp_pl_delta_off(Tint,mmsId)
%MMS_SDP_PL_DELTA_OFF  Delta offsets and FPI comparison
%
% res = MMS_SDP_PL_DELTA_OFF(Tint,mmsId)

fPre = sprintf('mms%d_edp_fast_l2a_dce2d',mmsId);
Bmask = mms.db_get_ts(fPre,...
  sprintf('mms%d_edp_dce_bitmask',mmsId), Tint);
bitmask = Bmask.data;
epochFull = Bmask.time.ttns;
P12 = mms.db_get_ts(fPre,...
  sprintf('mms%d_edp_dce_spinfit_e12',mmsId), Tint);
p12 = P12.data;
P34 = mms.db_get_ts(fPre,...
  sprintf('mms%d_edp_dce_spinfit_e34',mmsId), Tint);
p34 = P34.data;
epochSpin = P34.time.ttns;

mskAsponOn = bitand(bitmask(:,2),64) > 0;
mskAsponOn = mskAsponOn | (bitand(bitmask(:,3),64) > 0);

% Resample bitmask
spinSize = int64(20000000000);
mskAsponOnSpin = zeros(size(epochSpin));
ints = find_on(mskAsponOn);
for i=1:size(ints,1)
  mskAsponOnSpin((epochSpin> epochFull(ints(1,1))-spinSize/2) & ... 
    (epochSpin<= epochFull(ints(1,2))+spinSize/2)) = 1;
end
mskAsponOnSpin=logical(mskAsponOnSpin);

%
EpochS = EpochTT(epochSpin);
Es12 = irf.ts_vec_xy(EpochS,p12(:,3:4));
Es34 = irf.ts_vec_xy(EpochS,p34(:,3:4));
Es12AspocOff =  Es12(~mskAsponOnSpin); Es12AspocOn =  Es12(mskAsponOnSpin);
Es34AspocOff =  Es34(~mskAsponOnSpin); Es34AspocOn =  Es34(mskAsponOnSpin);
DeltaAspocOff = Es12AspocOff - Es34AspocOff;
DeltaAspocOn = Es12AspocOn - Es34AspocOn;

%% FPI
B = mms.get_data('dfg_ql_srvy',Tint,mmsId);
Vfpi = mms.get_data('Vi_gse_fpi_ql',Tint,mmsId);
if isempty(Vfpi)
  Nifpi = []; Efpi = [];
else
  Nifpi = mms.get_data('Ni_fpi_ql',Tint,mmsId);
  Vifpi = mms.get_data('Vi_gse_fpi_ql',Tint,mmsId);
  Efpi = irf_e_vxb(Vfpi,B.resample(Vfpi));
end
PSP = mms.db_get_ts(sprintf('mms%d_edp_fast_l2_scpot',mmsId),...
  sprintf('mms%d_edp_psp',mmsId),Tint);

%% resample to 1 min
epoch1min = fix(Tint.start.epochUnix/60):ceil(Tint.stop.epochUnix/60);
epoch1min = epoch1min*60;
Epoch1min = EpochUnix(epoch1min);

if ~isempty(PSP)
  PSPR = PSP.resample(Epoch1min,'median');
end
if ~isempty(Es12AspocOff), Es12AspocOffR = Es12AspocOff.resample(Epoch1min,'median');
else Es12AspocOffR = Es12AspocOff;
end
if ~isempty(Es12AspocOn), Es12AspocOnR = Es12AspocOn.resample(Epoch1min,'median');
else Es12AspocOnR = Es12AspocOn;
end
if ~isempty(Es34AspocOff), Es34AspocOffR = Es34AspocOff.resample(Epoch1min,'median');
else Es34AspocOffR = Es34AspocOff;
end
if ~isempty(Es34AspocOn), Es34AspocOnR = Es34AspocOn.resample(Epoch1min,'median');
else Es34AspocOnR = Es34AspocOn;
end
if ~isempty(Efpi)
  EfpiR = Efpi.resample(Epoch1min,'median');
end
if isempty(DeltaAspocOff), DeltaAspocOffR = DeltaAspocOff;
else DeltaAspocOffR = DeltaAspocOff.resample(Epoch1min,'median');
end
if isempty(DeltaAspocOn), DeltaAspocOnR = DeltaAspocOn;
else DeltaAspocOnR = DeltaAspocOn.resample(Epoch1min,'median');
end

idxMSH = [];
if  ~isempty(Nifpi)
  NifpiR = Nifpi.resample(Epoch1min,'median');
  VifpiR = Vifpi.resample(Epoch1min,'median');
  idxMSH = NifpiR.data>5 & VifpiR.x.data>-200;
end

%% Raw data figure
myCols = [[0 0 0];[.3 .3 .3];[0 0 1];[.2 .2 .8]];

h = irf_figure(93,8,'reset');
hca = irf_panel('B');
irf_plot(hca,B);
if any(B.abs.data>100), set(hca,'YLim',[-99 99]), end
ylabel(hca,'B [nT]'), irf_legend(hca,{'X','Y','Z'},[0.95, 0.95])

hca = irf_panel('Vfpi');
irf_plot(hca,Vfpi);
ylabel(hca,'Vi [km/s]'), irf_legend(hca,{'X','Y','Z'},[0.95, 0.95])

hca = irf_panel('Ni');
irf_plot(hca,Nifpi);
ylabel(hca,'Ni [cc]')
% ScPot
hca = axes('Position',get(hca,'Position'));
hl = irf_plot(hca,PSP); set(hl,'Color','b')
ylabel(hca,'PSP [V]'),xlabel(hca,'')
set(hca,'XAxisLocation','top','xtick',[]); % remove 'xtick' if xticks required
set(hca, 'YAxisLocation','right');
set(hca,'Color','none'); % color of axis
set(hca,'XColor','b','YColor','b');

hca = irf_panel('Delta_off'); set(hca,'ColorOrder',myCols)
irf_plot(hca,{DeltaAspocOffR.x,DeltaAspocOnR.x,DeltaAspocOffR.y,DeltaAspocOnR.y},'comp')

hold(hca,'on')
[~,idxTmp,idxTmp2] = intersect(DeltaAspocOffR.time.epoch,NifpiR.time.epoch(idxMSH));
DeltaAspocOffRes = DeltaAspocOffR(idxTmp);
NifpiRes = NifpiR(idxTmp2);
PSPRes = PSPR(idxTmp2);
irf_plot(hca,DeltaAspocOffRes,'.')
hold(hca,'off')
ylabel(hca,'Delta [mV/m]')
set(hca,'YLim',[-1.4 1.4])
irf_legend(hca,{'X','Y'},[0.95, 0.95])

hca = irf_panel('Ex'); set(hca,'ColorOrder',myCols)
irf_plot(hca,{Es12AspocOffR.x,Es12AspocOnR.x,...
  Es34AspocOffR.x,Es34AspocOnR.x},'comp');
if ~isempty(Efpi)
  hold(hca,'on'), irf_plot(hca,EfpiR.x,'.'), hold(hca,'off')
end
ylabel(hca,'Ex [mV/m]')

hca = irf_panel('Fpi_x'); set(hca,'ColorOrder',myCols)
if ~isempty(Efpi)
  irf_plot(hca,{EfpiR.x-Es12AspocOffR.x,EfpiR.x-Es12AspocOnR.x,...
    EfpiR.x-Es34AspocOffR.x,EfpiR.x-Es34AspocOnR.x},'comp')
end
ylabel(hca,'\Delta FPI x [mV/m]')
set(hca,'YLim',[-4.9 .9])
irf_legend(hca,{'12','34'},[0.95, 0.95])

hca = irf_panel('Ey'); set(hca,'ColorOrder',myCols)
irf_plot(hca,{Es12AspocOffR.y,Es12AspocOnR.y,...
  Es34AspocOffR.y,Es34AspocOnR.y},'comp');
if ~isempty(Efpi)
  hold(hca,'on'), irf_plot(hca,EfpiR.y,'.'), hold(hca,'off')
end
ylabel(hca,'Ey [mV/m]')

hca = irf_panel('Fpi_y'); set(hca,'ColorOrder',myCols)
if ~isempty(Efpi)
  irf_plot(hca,{EfpiR.y-Es12AspocOffR.y,EfpiR.y-Es12AspocOnR.y,...
    EfpiR.y-Es34AspocOffR.y,EfpiR.y-Es34AspocOnR.y},'comp')
end
ylabel(hca,'\Delta FPI Y [mV/m]')
set(hca,'YLim',[-1.9 1.9])
irf_legend(hca,{'12','34'},[0.95, 0.95])

%irf_plot_ylabels_align(h)
irf_zoom(h,'x',Tint)
mmsIdS = sprintf('MMS%d',mmsId);
title(h(1),mmsIdS)

set(gcf,'paperpositionmode','auto')
print('-dpng',['DeltaOff_' mmsIdS '_' irf_fname(Tint.start.epochUnix)])

%% Scatter plots
TintTmp = Es12AspocOffR.time(idxMSH);
res = struct('tint',EpochUnix(median(TintTmp.epochUnix)),...
  'p12',[],'p34',[],'p1234',[],'delta',DeltaAspocOffRes,'ni', NifpiRes,...
  'psp',PSPRes);
h = irf_figure(94,4,'reset');
figure(94), clf
clf
nRows = 3;
subplot(nRows,2,1)
[~,res.p12.x] = plot_xy(Es12AspocOffR.x.data(idxMSH),EfpiR.x.data(idxMSH));
title(mmsIdS),ylabel('Ex FPI [mV/m]'), xlabel('SDP 12 [mV/m]')

subplot(nRows,2,2)
[~,res.p12.y] = plot_xy(Es12AspocOffR.y.data(idxMSH),EfpiR.y.data(idxMSH));
ylabel('Ey FPI [mV/m]'), xlabel('SDP 12 [mV/m]')
title([Tint.start.utc(1) ' - ' Tint.stop.utc(1)])

subplot(nRows,2,3)
[~,res.p34.x] = plot_xy(Es34AspocOffR.x.data(idxMSH),EfpiR.x.data(idxMSH));
ylabel('Ex FPI [mV/m]'), xlabel('SDP 34 [mV/m]')

subplot(nRows,2,4)
[~,res.p34.y] = plot_xy(Es34AspocOffR.y.data(idxMSH),EfpiR.y.data(idxMSH));
ylabel('Ey FPI [mV/m]'), xlabel('SDP 34 [mV/m]')

subplot(nRows,2,5)
[~,res.p12.xy,residuals] = plot_mvregress(...
  Es12AspocOffR.data(idxMSH,:),EfpiR.data(idxMSH,:));
ylabel('E FPI [mV/m]'), xlabel('SDP 12 [mV/m]')
Es12AspocOffResidual1 = irf.ts_vec_xy(Es12AspocOffR.time(idxMSH),residuals(:,1:2));

subplot(nRows,2,6)
[~,res.p34.xy,residuals] = plot_mvregress(...
  Es34AspocOffR.data(idxMSH,:),EfpiR.data(idxMSH,:));
ylabel('E FPI [mV/m]'), xlabel('SDP 34 [mV/m]')
Es34AspocOffResidual1 = irf.ts_vec_xy(Es34AspocOffR.time(idxMSH),residuals(:,1:2));

if 0
subplot(4,2,7)
[~,res.p1234,residuals] = plot_mvregress(...
  [Es12AspocOffR.data(idxMSH,:) Es34AspocOffR.data(idxMSH,:)],...
  [EfpiR.data(idxMSH,1:2) EfpiR.data(idxMSH,1:2)]);
ylabel('E FPI [mV/m]'), xlabel('SDP [mV/m]')
Es12AspocOffResidual2 = irf.ts_vec_xy(Es12AspocOffR.time(idxMSH),residuals(:,1:2));
Es34AspocOffResidual2 = irf.ts_vec_xy(Es12AspocOffR.time(idxMSH),residuals(:,3:4));
end

set(gcf,'paperpositionmode','auto')
print('-dpng',['ScatterPlotNew' mmsIdS '_' irf_fname(Tint.start.epochUnix)])

%% Validation figure
% resample to 5 sec
%epoch5sec = fix(Tint.start.epochUnix/60)*60:5:ceil(Tint.stop.epochUnix/60)*60;
%Epoch5sec = EpochUnix(epoch5sec);
%EfpiR5 = Efpi.resample(Epoch5sec,'median');

Es12AspocOffCorr = Es12AspocOff; Es34AspocOffCorr = Es34AspocOff;
if 0
  Es12AspocOffCorr.data = Es12AspocOffCorr.data*res.p1234.slope;
  Es12AspocOffCorr.data(:,1) = Es12AspocOffCorr.data(:,1) + res.p1234.offs(1);
  Es12AspocOffCorr.data(:,2) = Es12AspocOffCorr.data(:,2) + res.p1234.offs(2);
  Es34AspocOffCorr.data = Es34AspocOffCorr.data*res.p1234.slope;
  Es34AspocOffCorr.data(:,1) = Es34AspocOffCorr.data(:,1) + res.p1234.offs(3);
  Es34AspocOffCorr.data(:,2) = Es34AspocOffCorr.data(:,2) + res.p1234.offs(4);
  Es12AspocOffResidual = Es12AspocOffResidual2;
  Es34AspocOffResidual = Es34AspocOffResidual2;
else
  Es12AspocOffCorr.data = Es12AspocOffCorr.data*res.p12.xy.slope;
  Es12AspocOffCorr.data(:,1) = Es12AspocOffCorr.data(:,1) + res.p12.xy.offs(1);
  Es12AspocOffCorr.data(:,2) = Es12AspocOffCorr.data(:,2) + res.p12.xy.offs(2);
  Es34AspocOffCorr.data = Es34AspocOffCorr.data*res.p34.xy.slope;
  Es34AspocOffCorr.data(:,1) = Es34AspocOffCorr.data(:,1) + res.p34.xy.offs(1);
  Es34AspocOffCorr.data(:,2) = Es34AspocOffCorr.data(:,2) + res.p34.xy.offs(2);
  Es12AspocOffResidual = Es12AspocOffResidual1;
  Es34AspocOffResidual = Es34AspocOffResidual1;
end

h = irf_figure(95,6,'reset');

hca = irf_panel('B');
irf_plot(hca,B);
if any(B.abs.data>100), set(hca,'YLim',[-99 99]), end
ylabel(hca,'B [nT]'), irf_legend(hca,{'X','Y','Z'},[0.95, 0.95])

hca = irf_panel('PSP');
irf_plot(hca,PSP), ylabel(hca,'PSP [V]')

hca = irf_panel('Ex');
irf_plot(hca,{Efpi.x,Es12AspocOffCorr.x,Es34AspocOffCorr.x},'comp')
ylabel(hca,'Ex [mV/m]')
set(hca,'Ylim',9*[-1 1])

myCols = [[0 0 1];[1 0 0];];
hca = irf_panel('Ex_res'); set(hca,'ColorOrder',myCols)
irf_plot(hca,{Es12AspocOffResidual.x,Es34AspocOffResidual.x},'comp')
ylabel(hca,'Ex-res [mV/m]')
set(hca,'Ylim',1.4*[-1 1])

hca = irf_panel('Ey');
irf_plot(hca,{Efpi.y,Es12AspocOffCorr.y,Es34AspocOffCorr.y},'comp')
ylabel(hca,'Ey [mV/m]')
set(hca,'Ylim',9*[-1 1])

hca = irf_panel('Ey_res');  set(hca,'ColorOrder',myCols)
irf_plot(hca,{Es12AspocOffResidual.y,Es34AspocOffResidual.y},'comp')
ylabel(hca,'Ey-res [mV/m]')
set(hca,'Ylim',1.4*[-1 1])

irf_zoom(h,'x',Tint)

title(h(1),mmsIdS)

set(gcf,'paperpositionmode','auto')
print('-dpng',['Verification' mmsIdS '_' irf_fname(Tint.start.epochUnix)])
end



function ints = find_on(mask)

idxJump = find(diff(mask)~=0);

ints = []; iStop = [];
for i=1:length(idxJump)+1
  if isempty(iStop), iStart = 1; else iStart = iStop + 1; end
  if i==length(idxJump)+1, iStop = length(mask); else iStop = idxJump(i); end
  if ~mask(iStart), continue, end
  ints = [ ints; iStart iStop]; %#ok<AGROW>
end

end

function [h,fitParams] = plot_xy(x,y)

idx = isnan(x); x(idx) = []; y(idx) = [];
idx = isnan(y); x(idx) = []; y(idx) = [];

p=polyfit( x,y,1);
d = polyval(p,x)-y;
idx = abs(d)<3*std(d); idxOut = abs(d)>=3*std(d); % remove outlyers
p=polyfit( x(idx),y(idx),1);
cc=corrcoef(y(idx),x(idx));
slope = p(1); offs = p(2); corr_coef = cc(1,2);

h = plot(x(idx),y(idx),'.',x(idxOut),y(idxOut),'o');    
ax=axis; set(gca,'YLim',10*[-1 1],'XLim',10*[-1 1])
ymax=ax(4);ymin=ax(3);dy=(ymax-ymin)/20;
ytext=ymax-dy;
xtext=ax(1)+(ax(2)-ax(1))/20;

hold on
xp=[min(x) max(x)];
plot(xp,polyval(p,xp),'k-');
axis(ax);
text(xtext,ytext,...
  ['slope=' num2str(slope,3) '  offs=' num2str(offs,2)]);ytext=ytext-dy;
text(xtext,ytext,['cc=' num2str(corr_coef,3)]);

fitParams = struct('slope',slope,'offs',offs,'corrCoef',corr_coef,'range',xp);
end

function [h,fitParams,residuals] = plot_mvregress(x,y)

residuals = nan(size(x));
idx = ~isnan(x(:,1)) & ~isnan(y(:,1)); 

x = x(idx,:); y = y(idx,:);

n=size(x,1);
d=size(x,2);
X = cell(n,1);

for i=1:n
    X{i} = [eye(d) x(i,1:d)'];
end
[beta,~,residualsTmp] = mvregress(X,y(:,1:d));
residuals(idx,:) = residualsTmp;

idxTmp = [];
if 1 % disregard points with > 3*std
ia = abs(residualsTmp)<3*repmat(std(residualsTmp),n,1);
idxTmp = ia(:,1);
for i=2:d, idxTmp = idxTmp & ia(:,i); end
[beta,~,residualsTmp2] = mvregress(X(idxTmp),y(idxTmp,1:d));
residualsTmp(idxTmp,:) = residualsTmp2;
residualsTmp(~idxTmp,:) = NaN; 
residuals(idx,:) = residualsTmp;
end

slope = beta(end); offs = beta(1:end-1); corr_coef = [];

%%   
cols = 'krgb';
ax=axis; set(gca,'YLim',10*[-1 1],'XLim',10*[-1 1])
ax=axis; 
ymax=ax(4);ymin=ax(3);dy=(ymax-ymin)/10;
ytext=ymax-dy; xtext=ax(1)+(ax(2)-ax(1))/20;

hold on
    
xp = zeros(d,2);
for i=1:d
  plot(x(:,i),y(:,i),[cols(i) '.'])
  if ~isempty(idxTmp), plot(x(~idxTmp,i),y(~idxTmp,i),[cols(i) 'o']), end
  if i==1
    text(xtext,ytext,['slope=' num2str(slope,3)]), ytext=ytext-dy;
  end
  text(xtext,ytext,['offs=' num2str(offs(i),2)]), ytext=ytext-dy;
  p = [slope offs(i)]; xp(i,:)=[min(x(:,i)) max(x(:,i))];
  plot(xp(i,:),polyval(p,xp(i,:)),[cols(i) '-']);
end
hold off
h = ax;
fitParams = struct('slope',slope,'offs',offs,'corrCoef',corr_coef,'range',xp);
end