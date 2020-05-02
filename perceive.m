function perceive(files,subjects,Format)
% files should be a cell array
% ADD PATIENT SNAPSHOTS
% ADD Lead DBS Implementation

if ~exist('files','var')
    files=ffind('*.json');
end

if ~exist('format','var')
    Format = 'spm';
end


if ischar(files)
    files = {files};
end
if exist('subjects','var') && ischar(subjects)
    subjects={subjects};
end

for a = 1:length(files)
    filename = files{a};
    
    
    js = jsondecode(fileread(filename));
    
    infofields = {'SessionDate','SessionEndDate','PatientInformation','DeviceInformation','BatteryInformation','LeadConfiguration','Stimulation','Groups','Stimulation','Impedance'};
    for b = 1:length(infofields)
        hdr.(infofields{b})=js.(infofields{b});
    end
    
    hdr.SessionEndDate = datetime(strrep(js.SessionEndDate(1:end-1),'T',' '));
    hdr.SessionDate = datetime(strrep(js.SessionDate(1:end-1),'T',' '));
    hdr.Diagnosis = strsplit(js.PatientInformation.Final.Diagnosis,'.');hdr.Diagnosis=hdr.Diagnosis{2};
    hdr.ImplantDate = strrep(strrep(js.DeviceInformation.Final.ImplantDate(1:end-1),'T','_'),':','-');
    hdr.BatteryPercentage = js.BatteryInformation.BatteryPercentage;
    hdr.LeadLocation = strsplit(hdr.LeadConfiguration.Final(1).LeadLocation,'.');hdr.LeadLocation=hdr.LeadLocation{2};
    if ~exist('subjects')
        hdr.subject = ['sub-' strrep(strtok(hdr.ImplantDate,'_'),'-','') hdr.Diagnosis(1) hdr.LeadLocation];
    else
        hdr.subject = subjects{a};
    end
    hdr.session = ['ses-' char(datetime(hdr.SessionDate,'Format','yyyyMMddhhmmss')) num2str(hdr.BatteryPercentage)];
    
    if ~exist(fullfile(hdr.subject,hdr.session,'ieeg'),'dir')
        mkdir(fullfile(hdr.subject,hdr.session,'ieeg'));
    end
    
    hdr.fpath = fullfile(hdr.subject,hdr.session,'ieeg');
    hdr.events = js.DiagnosticData.EventLogs;
    hdr.fname = [hdr.subject '_' hdr.session];
    hdr.chan = ['LFP_' hdr.LeadLocation];
    hdr.d0 = datetime(js.SessionDate(1:10));
    hdr.js = js;
    copyfile(filename,fullfile(hdr.fpath,[hdr.fname '.json']));
    datafields = sort({'BrainSenseLfp','BrainSenseTimeDomain','LfpMontageTimeDomain','IndefiniteStreaming','LFPMontage','CalibrationTests'});
    
    alldata = {};
    for b = 1:length(datafields)
        data=[];
        if isfield(js,datafields{b})
            
            switch datafields{b}
                case 'BrainSenseTimeDomain'
                    data = js.(datafields{b});
                    FirstPacketDateTime = strrep(strrep({data(:).FirstPacketDateTime},'T',' '),'Z','');
                    runs = unique(FirstPacketDateTime);
                    
                    Pass = {data(:).Pass};
                    tmp =  {data(:).GlobalSequences};
                    for c = 1:length(tmp)
                        GlobalSequences(c,:) = str2double(tmp{c});
                    end
                    tmp =  {data(:).GlobalPacketSizes};
                    for c = 1:length(tmp)
                        GlobalPacketSizes(c,:) = str2double(tmp{c});
                    end
                    
                    fsample = data.SampleRateInHz;
                    gain=[data(:).Gain]';
                    [tmp1,tmp2] = strtok(strrep({data(:).Channel}','_AND',''),'_');
                    ch1 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    
                    [tmp1,tmp2] = strtok(tmp2,'_');
                    ch2 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    side = strrep(strrep(strtok(tmp2,'_'),'LEFT','L'),'RIGHT','R');
                    Channel = strcat(hdr.chan,'_',side,'_', ch1, ch2);
                    d=[];
                    for c = 1:length(runs)
                        i=ci(runs{c},FirstPacketDateTime);
                        raw=[data(i).TimeDomainData]';
                        d.hdr = hdr;
                        d.datatype = datafields{b};
                        d.hdr.CT.Pass=strrep(strrep(unique(strtok(Pass(i),'_')),'FIRST','1'),'SECOND','2');
                        d.hdr.CT.GlobalSequences=GlobalSequences(i,:);
                        d.hdr.CT.GlobalPacketSizes=GlobalPacketSizes(i,:);
                        d.hdr.CT.FirstPacketDateTime = runs{c};
                        
                        d.label=Channel(i);
                        d.trial{1} = raw;
                        d.time{1} = linspace(seconds(datetime(runs{c})-hdr.d0),seconds(datetime(runs{c})-hdr.d0)+size(d.trial{1},2)/fsample,size(d.trial{1},2));
                        
                        d.fsample = fsample;
                        firstsample = 1+round(fsample*seconds(datetime(runs{c})-datetime(FirstPacketDateTime{1})));
                        lastsample = firstsample+size(d.trial{1},2);
                        d.sampleinfo(1,:) = [firstsample lastsample];
                        d.trialinfo(1) = c;
       
             
                        d.fname = [hdr.fname '_run-BSTD' char(datetime(runs{c},'Format','yyyyMMddhhmmss'))];
                        d.hdr.Fs = d.fsample;
                        d.hdr.label = d.label;
                        alldata{length(alldata)+1} = d;
                    end
                case 'BrainSenseLfp'
                    data = js.(datafields{b});
                    FirstPacketDateTime = strrep(strrep({data(:).FirstPacketDateTime},'T',' '),'Z','');
                    runs = unique(FirstPacketDateTime);
                    bsldata=[];bsltime=[];bslchannels=[];
                    figure
                    for c=1:length(runs)
                        cdata = data(c);
                        tmp = strrep(cdata.Channel,'_AND','');
                        tmp = strsplit(strrep(strrep(strrep(strrep(strrep(tmp,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3'),'_',''),',');
                        lfpchannels = {[hdr.chan '_' tmp{1}(3) '_' tmp{1}(1:2)],[hdr.chan '_' tmp{2}(3) '_' tmp{2}(1:2)]};
                        d=[];
                        d.hdr = hdr;
                        d.hdr.BSL.TherapySnapshot = cdata.TherapySnapshot;
                        tmp = d.hdr.BSL.TherapySnapshot.Left;
                        stimchannels = ['STIM_L' num2str(tmp.RateInHertz) 'Hz' num2str(tmp.PulseWidthInMicroSecond) 'us_PEAK' strrep(num2str(tmp.FrequencyInHertz,3),'.','-') 'Hz_THR' num2str(tmp.LowerLfpThreshold) '-' num2str(tmp.UpperLfpThreshold) '_AVG' num2str(tmp.AveragingDurationInMilliSeconds/1000) 's'];
                        tmp = d.hdr.BSL.TherapySnapshot.Right;
                        stimchannels = {stimchannels,['R' num2str(tmp.RateInHertz) 'Hz' num2str(tmp.PulseWidthInMicroSecond) 'us_' strrep(num2str(tmp.FrequencyInHertz,3),'.','-') '_THR' num2str(tmp.LowerLfpThreshold) '-' num2str(tmp.UpperLfpThreshold) '_AVG' num2str(tmp.AveragingDurationInMilliSeconds/1000) 's']};
                        
                        d.label = [lfpchannels stimchannels];
                        d.hdr.label = d.label;
                        
                        d.fsample = cdata.SampleRateInHz;
                        d.hdr.Fs = d.fsample;
                        for e =1:length(cdata.LfpData)
                            d.trial{1}(1:2,e) = [cdata.LfpData(e).Left.LFP;cdata.LfpData(e).Right.LFP]./1000;
                            d.trial{1}(3:4,e) = [cdata.LfpData(e).Left.mA;cdata.LfpData(e).Right.mA];
                            d.time{1}(e) = cdata.LfpData(e).TicksInMs/1000;
                            d.realtime(e) = datetime(runs{c})+seconds(d.time{1}(e)-d.time{1}(1));
                            d.hdr.BSL.seq(e)= cdata.LfpData(e).Seq;
                        end
                        d.trialinfo(1) = c;
                        d.hdr.realtime = d.realtime;
              
      
                        d.fname = [hdr.fname '_run-BSL' char(datetime(runs{c},'Format','yyyyMMddhhmmss'))];
                        
                        p=plot(d.realtime,d.trial{1}./1000,'linewidth',2);
                        cc=[1 0 0; 0 0 1; .2 .2 .2; .5 .5 .5];
                        for e =1:length(p)
                            set(p(e),'color',cc(e,:));
                        end
                        legend(wjn_strrep(d.label))
                        hold on
                        xlabel('Time')
                        ylabel('Amplitude')
                        bsldata = [bsldata,d.trial{1}];
                        bsltime = [bsltime,d.realtime];
                        bslchannels = d.label;
                        alldata{length(alldata)+1} = d;
                    end
                    title({wjn_strrep(hdr.fname),'BrainSenseLfp'})
                    savefig(fullfile(hdr.fpath,[hdr.fname '_BrainSenseLfp']))
                    myprint(fullfile(hdr.fpath,[hdr.fname '_BrainSenseLfp']))
                    T=table;
                    T.time = bsltime';
                    T(:,2:5)=array2table(bsldata','VariableNames',bslchannels);
                    writetable(T,fullfile(hdr.fpath,[hdr.fname '_BrainSenseLfp.csv']))
                    
                case 'LfpMontageTimeDomain'
                    data = js.LfpMontageTimeDomain;
                    FirstPacketDateTime = strrep(strrep({data(:).FirstPacketDateTime},'T',' '),'Z','');
                    runs = unique(FirstPacketDateTime);
                    
                    Pass = {data(:).Pass};
                    tmp =  {data(:).GlobalSequences};
                    for c = 1:length(tmp)
                        GlobalSequences(c,:) = str2double(tmp{c});
                    end
                    tmp =  {data(:).GlobalPacketSizes};
                    for c = 1:length(tmp)
                        GlobalPacketSizes(c,:) = str2double(tmp{c});
                    end
                    
                    fsample = data.SampleRateInHz;
                    gain=[data(:).Gain]';
                    [tmp1,tmp2] = strtok(strrep({data(:).Channel}','_AND',''),'_');
                    ch1 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    
                    [tmp1,tmp2] = strtok(tmp2,'_');
                    ch2 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    side = strrep(strrep(strtok(tmp2,'_'),'LEFT','L'),'RIGHT','R');
                    Channel = strcat(hdr.chan,'_',side,'_', ch1, ch2);
                    d=[];
                    for c = 1:length(runs)
                        i=ci(runs{c},FirstPacketDateTime);
                        d.hdr = hdr;
                        d.datatype = datafields{b};
                        d.hdr.IS.Pass=strrep(strrep(unique(strtok(Pass(i),'_')),'FIRST','1'),'SECOND','2');
                        d.hdr.IS.GlobalSequences=GlobalSequences(i,:);
                        d.hdr.IS.GlobalPacketSizes=GlobalPacketSizes(i,:);
                        d.hdr.IS.FirstPacketDateTime = runs{c};
                        tmp = [data(i).TimeDomainData]';
                        d.trial{1} = [tmp];
                        d.label=Channel(i);
                        d.time{1} = linspace(seconds(datetime(runs{c})-hdr.d0),seconds(datetime(runs{c})-hdr.d0)+size(d.trial{1},2)/fsample,size(d.trial{1},2));
                        d.fsample = fsample;
                        firstsample = 1+round(fsample*seconds(datetime(runs{c})-datetime(FirstPacketDateTime{1})));
                        lastsample = firstsample+size(d.trial{1},2);
                        d.sampleinfo(1,:) = [firstsample lastsample];
                        d.trialinfo(1) = c;
      
                        d.hdr.label = d.label;
                        d.hdr.Fs = d.fsample;
                        d.fname = [hdr.fname '_run-LMTD' char(datetime(runs{c},'Format','yyyyMMddhhmmss'))];
                        alldata{length(alldata)+1} = d;
                    end
                case 'LFPMontage'
                    data = js.LFPMontage;
                    channels={};
                    pow=[];rpow=[];lfit=[];bad=[];
                    for c = 1:length(data)
                        cdata = data(c);
                        if iscell(cdata)
                            cdata=cdata{1};
                        end
                        tmp=strsplit(cdata.Hemisphere,'.');
                        side=tmp{2}(1);
                        tmp=strsplit(cdata.SensingElectrodes,'.');tmp=strrep(tmp{2},'_AND_','');
                        ch = strrep(strrep(strrep(strrep(tmp,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                        channels{c} = [hdr.chan '_' side '_' ch];
                        freq = cdata.LFPFrequency;
                        pow(c,:) = cdata.LFPMagnitude;
                        rpow(c,:) = wjn_raw_power_normalization(pow(c,:),freq);
                        lfit(c,:) = fftlogfitter(freq,pow(c,:));
                        bad(c,1) = strcmp('IFACT_PRESENT',cdata.ArtifactStatus(end-12:end));
                        
                        try
                            peaks(c,1) = cdata.PeakFrequencyInHertz;
                            peaks(c,2) = cdata.PeakMagnitudeInMicroVolt;
                        catch
                            peaks(c,:)=nan(1,2);
                        end
                    end
                    
                    T=array2table([freq';pow;rpow;lfit]','VariableNames',[{'Frequency'};strcat({'POW'},channels');strcat({'RPOW'},channels');strcat({'LFIT'},channels')]);
                    writetable(T,fullfile(hdr.fpath,[hdr.fname '_run-LFPMontagePowerSpectra.csv']));
                    T=array2table(peaks','VariableNames',channels,'RowNames',{'PeakFrequency','PeakPower'});
                    writetable(T,fullfile(hdr.fpath,[hdr.fname '_run-LFPMontage_Peaks.csv']));
                    
                    figure
                    ir = ci([hdr.chan '_R'],channels);
                    subplot(1,2,1)
                    p=plot(freq,pow(ir,:));
                    set(p(find(bad(ir))),'linestyle','--')
                    hold on
                    plot(freq,nanmean(pow),'color','k','linewidth',2)
                    xlim([1 35])
                    plot(peaks(ir,1),peaks(ir,2),'LineStyle','none','Marker','.','MarkerSize',12)
                    for c = 1:length(ir)
                        if peaks(ir(c),1)>0
                            text(peaks(ir(c),1),peaks(ir(c),2),[' ' num2str(peaks(ir(c),1),3) ' Hz'])
                        end
                    end
                    xlabel('Frequency [Hz]')
                    ylabel('Power spectral density [uV²/Hz]')
                    title(wjn_strrep({hdr.subject,char(hdr.SessionDate),'RIGHT'}))
                    legend(wjn_strrep(channels(ir)))
                    il = ci([hdr.chan '_L'],channels);
                    subplot(1,2,2)
                    p=plot(freq,pow(il,:));
                    set(p(find(bad(il))),'linestyle','--')
                    hold on
                    plot(freq,nanmean(pow),'color','k','linewidth',2)
                    xlim([1 35])
                    title(wjn_strrep({hdr.subject,char(hdr.SessionDate),'LEFT'}))
                    plot(peaks(il,1),peaks(il,2),'LineStyle','none','Marker','.','MarkerSize',12)
                    xlabel('Frequency [Hz]')
                    ylabel('Power spectral density [uV²/Hz]')
                    for c = 1:length(il)
                        if peaks(il(c),1)>0
                            text(peaks(il(c),1),peaks(il(c),2),[' ' num2str(peaks(il(c),1),3) ' Hz'])
                        end
                    end
                    legend(wjn_strrep(channels(il)))
                    savefig(fullfile(hdr.fpath,[hdr.fname '_run-LFPMontage.fig']))
                    myprint(fullfile(hdr.fpath,[hdr.fname '_run-LFPMontage']))
                    
                    
                case 'IndefiniteStreaming'
                    data = js.IndefiniteStreaming;
                    FirstPacketDateTime = strrep(strrep({data(:).FirstPacketDateTime},'T',' '),'Z','');
                    runs = unique(FirstPacketDateTime);
                    
                    Pass = {data(:).Pass};
                    tmp =  {data(:).GlobalSequences};
                    for c = 1:length(tmp)
                        GlobalSequences(c,:) = str2double(tmp{c});
                    end
                    tmp =  {data(:).GlobalPacketSizes};
                    for c = 1:length(tmp)
                        GlobalPacketSizes(c,:) = str2double(tmp{c});
                    end
                    
                    fsample = data.SampleRateInHz;
                    gain=[data(:).Gain]';
                    [tmp1,tmp2] = strtok(strrep({data(:).Channel}','_AND',''),'_');
                    ch1 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    
                    [tmp1,tmp2] = strtok(tmp2,'_');
                    ch2 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    side = strrep(strrep(strtok(tmp2,'_'),'LEFT','L'),'RIGHT','R');
                    Channel = strcat(hdr.chan,'_',side,'_', ch1, ch2);
                    d=[];
                    for c = 1:length(runs)
                        i=ci(runs{c},FirstPacketDateTime);
                        d.hdr = hdr;
                        d.datatype = datafields{b};
                        d.hdr.IS.Pass=strrep(strrep(unique(strtok(Pass(i),'_')),'FIRST','1'),'SECOND','2');
                        d.hdr.IS.GlobalSequences=GlobalSequences(i,:);
                        d.hdr.IS.GlobalPacketSizes=GlobalPacketSizes(i,:);
                        d.hdr.IS.FirstPacketDateTime = runs{c};
                        tmp =  [data(i).TimeDomainData]';;
                        xchans = ci({'L_03','L_13','L_02','R_03','R_13','R_02'},Channel(i));
                        nchans = {'L_01','L_12','L_23','R_01','R_12','R_23'};
                        refraw = [tmp(xchans(1),:)-tmp(xchans(2),:);(tmp(xchans(1),:)-tmp(xchans(2),:))-tmp(xchans(3),:);tmp(xchans(3),:)-tmp(xchans(1),:);
                            tmp(xchans(4),:)-tmp(xchans(5),:);(tmp(xchans(4),:)-tmp(xchans(5),:))-tmp(xchans(6),:);tmp(xchans(6),:)-tmp(xchans(4),:)];
                        d.trial{1} = [refraw;tmp];
                        d.label=[Channel(i);strcat(hdr.chan,'_',nchans')];
                        d.time{1} = linspace(seconds(datetime(runs{c})-hdr.d0),seconds(datetime(runs{c})-hdr.d0)+size(d.trial{1},2)/fsample,size(d.trial{1},2));
                        d.fsample = fsample;
                        firstsample = 1+round(fsample*seconds(datetime(runs{c})-datetime(FirstPacketDateTime{1})));
                        lastsample = firstsample+size(d.trial{1},2);
                        d.sampleinfo(1,:) = [firstsample lastsample];
                        d.trialinfo(1) = c;
                        d.hdr.label=d.label;
                        d.hdr.Fs = d.fsample;

                        d.fname = [hdr.fname '_run-IS' char(datetime(runs{c},'Format','yyyyMMddhhmmss'))];
                        alldata{length(alldata)+1} = d;
                    end
                    
                case 'CalibrationTests'
                    data = js.CalibrationTests;
                    FirstPacketDateTime = strrep(strrep({data(:).FirstPacketDateTime},'T',' '),'Z','');
                    runs = unique(FirstPacketDateTime);
                    hdr.d0=datetime(FirstPacketDateTime{1});
                    Pass = {data(:).Pass};
                    tmp =  {data(:).GlobalSequences};
                    for c = 1:length(tmp)
                        GlobalSequences(c,:) = str2double(tmp{c});
                    end
                    tmp =  {data(:).GlobalPacketSizes};
                    for c = 1:length(tmp)
                        GlobalPacketSizes(c,:) = str2double(tmp{c});
                    end
                    hdr.d0=datetime(FirstPacketDateTime{1});
                    fsample = data.SampleRateInHz;
                    gain=[data(:).Gain]';
                    [tmp1,tmp2] = strtok(strrep({data(:).Channel}','_AND',''),'_');
                    ch1 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    
                    [tmp1,tmp2] = strtok(tmp2,'_');
                    ch2 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    side = strrep(strrep(strtok(tmp2,'_'),'LEFT','L'),'RIGHT','R');
                    Channel = strcat(hdr.chan,'_',side,'_', ch1, ch2);
                    d=[];
                    for c = 1:length(runs)
                        i=ci(runs{c},FirstPacketDateTime);
                        raw=[data(i).TimeDomainData]';
                        d.hdr = hdr;
                        d.datatype = datafields{b};
                        d.hdr.CT.Pass=strrep(strrep(unique(strtok(Pass(i),'_')),'FIRST','1'),'SECOND','2');
                        d.hdr.CT.GlobalSequences=GlobalSequences(i,:);
                        d.hdr.CT.GlobalPacketSizes=GlobalPacketSizes(i,:);
                        d.hdr.CT.FirstPacketDateTime = runs{c};
                        
                        d.label=Channel(i);
                         d.trial{1} = raw;
                        d.time{1} = linspace(seconds(datetime(runs{c})-hdr.d0),seconds(datetime(runs{c})-hdr.d0)+size(d.trial{1},2)/fsample,size(d.trial{1},2));
                       
                        d.fsample = fsample;
                        firstsample = 1+round(fsample*seconds(datetime(runs{c})-datetime(FirstPacketDateTime{1})));
                        lastsample = firstsample+size(d.trial{1},2);
                        d.sampleinfo(1,:) = [firstsample lastsample];
                        d.trialinfo(1) = c;
                        d.hdr.label = d.label;
                        d.hdr.Fs = d.fsample;

                        d.fname = [hdr.fname '_run-CT' char(datetime(runs{c},'Format','yyyyMMddhhmmss'))];
                        alldata{length(alldata)+1} = d;
                    end
                case 'SenseChannelTests'
                    data = js.SenseChannelTests;
                    FirstPacketDateTime = strrep(strrep({data(:).FirstPacketDateTime},'T',' '),'Z','');
                    runs = unique(FirstPacketDateTime);
                    
                    Pass = {data(:).Pass};
                    tmp =  {data(:).GlobalSequences};
                    for c = 1:length(tmp)
                        GlobalSequences(c,:) = str2double(tmp{c});
                    end
                    tmp =  {data(:).GlobalPacketSizes};
                    for c = 1:length(tmp)
                        GlobalPacketSizes(c,:) = str2double(tmp{c});
                    end
                    raw = [data(:).TimeDomainData]';
                    fsample = data.SampleRateInHz;
                    gain=[data(:).Gain]';
                    [tmp1,tmp2] = strtok(strrep({data(:).Channel}','_AND',''),'_');
                    ch1 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    
                    [tmp1,tmp2] = strtok(tmp2,'_');
                    ch2 = strrep(strrep(strrep(strrep(tmp1,'ZERO','0'),'ONE','1'),'TWO','2'),'THREE','3');
                    side = strrep(strrep(strtok(tmp2,'_'),'LEFT','L'),'RIGHT','R');
                    Channel = strcat(hdr.chan,'_',side,'_', ch1, ch2);
                    d=[];
                    for c = 1:length(runs)
                        i=ci(runs{c},FirstPacketDateTime);
                        d.hdr = hdr;
                        d.datatype = datafields{b};
                        d.hdr.IS.Pass=strrep(strrep(unique(strtok(Pass(i),'_')),'FIRST','1'),'SECOND','2');
                        d.hdr.IS.GlobalSequences=GlobalSequences(i,:);
                        d.hdr.IS.GlobalPacketSizes=GlobalPacketSizes(i,:);
                        d.hdr.IS.FirstPacketDateTime = runs{c};
                        tmp = raw(i,:);
                        d.trial{1} = [tmp];
                        d.label=Channel(i);
                        d.time{1} = linspace(seconds(datetime(runs{c})-hdr.d0),seconds(datetime(runs{c})-hdr.d0)+size(d.trial{1},2)/fsample,size(d.trial{1},2));
                        d.fsample = fsample;
                        firstsample = 1+round(fsample*seconds(datetime(runs{c})-datetime(FirstPacketDateTime{1})));
                        lastsample = firstsample+size(d.trial{1},2);
                        d.sampleinfo(1,:) = [firstsample lastsample];
                        d.trialinfo(1) = c;
 
                        d.hdr.label = d.label;
                        d.hdr.Fs = d.fsample;
                        d.fname = [hdr.fname '_run-SCT' char(datetime(runs{c},'Format','yyyyMMddhhmmss'))];
                        alldata{length(alldata)+1} = d;
                    end
            end
            
            
            
        end
    end
    
    
    for b = 1:length(alldata)
        fullname = fullfile('.',hdr.fpath,alldata{b}.fname);
        switch Format
            case 'spm'
                data=ft_preprocessing([],alldata{b});
                data.hdr.original_time =data.time;
                data.time{1}=data.time{1}-data.time{1}(1);

                D=spm_eeg_ft2spm(alldata{b},[fullname '.mat']);
                D=chantype(D,':','LFP');
                D.percept = hdr;save(D);
            case 'mne'
                fieldtrip2fiff([fullname '.fif'],alldata{b})
            case 'ft'
                data=alldata{b};
                save([fullname '.mat'],data)
        end
    end
    
end


end