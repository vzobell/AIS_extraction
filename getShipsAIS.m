% getShipAIS

% stolen from getShipsAIS_CINMS_B_180820.m -> BJT
% to work with Shipplotter decoded AIS files 180912 smw
% 2020 KF added Marine Cadastre as input file type option. Not all marine
% cadastre years will work, because of formatting changes on their end 
% (pre 2015 = nope).
clear variables


% SETTINGS
% set AIS decoded file type:
aisType = 3; % SBARC=1, Shipplotter=2, Marine Cadastre=3

boundd_m = 20e3; % in [m] % <- Define your box here, in meters from center.

siteLatLon = [ 34.2755, -120.0185 ];%<-insert your site lat longs here, decimal degrees!

plotOn = 0; % if 1 = shows quick plot of transit, if 0 = no plots. 
            % Warning: There is no pause after plotting, so plots may go by
            % quickly if turned on. Can add a pause or breakpoint on line
            % ~191 to stop and look.
            
            
% Define a wildcard to match the names of your input files:
% aisFileWildCard = AIS_SBARC_*.txt'; typical option 1 wildcard
% aisFileWildCard = 'shipplotter*.log'; %typical option 2 wildcard
aisFileWildCard = 'AIS*.csv'; %typical option 3 wildcard
                    
inDir = 'F:\MarineCadastre\CINMSonly'; % where the AIS files live

outDir = 'F:\MarineCadastre\matFilesMarCad'; % where to save the extracted AIS info

outName = 'siteB_AIS'; % string to start your output file names with
%%%%%%%%%%%%%%%%%%%%%%%% Main Body %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5

rlat = siteLatLon(1) * pi/180;
% Ref: American Practical Naviagator, Bowditch 1958, table 6 (explanation)
% page 1187
m = 111132.09 - 566.05 * cos(2*rlat) + 1.2 * cos(4*rlat) - 0.003 * cos(6*rlat);
p = 111415.10 * cos(rlat) - 94.55 * cos(3*rlat) - 0.12 * cos(5*rlat);


% for starters, let's filter for any ships inside some lat/lon box
maxLat = [ siteLatLon(1)-boundd_m/m, siteLatLon(1)+boundd_m/m ];
maxLon = [ siteLatLon(2)-boundd_m/p, siteLatLon(2)+boundd_m/p ];

aisFiles = ls(fullfile(inDir,aisFileWildCard));

if aisType>3 ||aisType<1
    error('unknown decoded AIS type')
end

if ~isfolder(outDir) % no folder? make it
    mkdir(outDir)
end

NF = size(aisFiles,1);
for f = 1:NF
    aisFile = fullfile(inDir,aisFiles(f,:));
    if contains(aisFile,'NMEA') || contains(aisFile,'nmea')...
            && aisType~=3
        % don't want to use coded AIS
        continue
    end
    
    if aisType ~=3
        dstamp = regexp(aisFile,'[0-9]{6}','match');
    else
        dstampOrig = char(regexp(aisFile,'[0-9]{4}_[0-9]{2}','match'));
        dstamp = {datestr(datenum([str2num(dstampOrig(1:4)),str2num(dstampOrig(6:7)),01]),'yymmdd')};
    end
    ofn = sprintf('%s_%dm_%s.mat',outName,boundd_m,dstamp{1});
    offn = fullfile(outDir,ofn);
    
   
    finfo = dir(aisFile);
    % on BJT machine processes ~350 kbytes/sec
    est_rt = (finfo.bytes/350e3)/60;
    [ ~, fname, ext ] = fileparts(aisFile);
    fprintf('%s: %s%s ~%.2f minutes to process\n', ...
        datestr(now,'mm/dd/yy HH:MM:SS'),fname,ext, est_rt);
    %     tic
    try
        switch aisType
            case 1
                [ msg13_char, msg13_num, msg5_char, msg5_num ] = parseDecodedSBARC_180814(aisFile);
            case 2
                [ msg13_char, msg13_num, msg5_char, msg5_num ] = parseDecodedShipplotter_180912(aisFile);
            case 3
                [ msg13_char, msg13_num, msg5_char, msg5_num ] = parseDecodedMarCadastre(aisFile);
                
            otherwise
                disp('unknown decoded AIS type')
        end
    catch ME
        fprintf('\tParse fail: %s\n',ME.message);
        continue
    end
    %     toc
    
    % work on message IDs 1-3 first
    lats = msg13_num(:,6);
    lons = msg13_num(:,5);
    
    %     msg13_char0 = msg13_char;
    %     msg13_num0 = msg13_num;
    xIdx = find(lats >= maxLat(1) & lats <= maxLat(2));
    yIdx = find(lons >= maxLon(1) & lons <= maxLon(2));
    
    clear lats lons
    gIdx = intersect(xIdx, yIdx);
    msg13_char = msg13_char(gIdx,:);
    msg13_num = msg13_num(gIdx,:);
    
    if ~isempty(msg13_num)
        shipTracks = struct;
        % get unique ships via MMSI number
        uShips = unique(msg13_num(:,2));
        fprintf('\t%d ships found:\n',length(uShips));
        sInc = 1;
        for s = 1:length(uShips)
            s13idx = find(msg13_num(:,2)==uShips(s));
            s5idx = find(msg5_num(:,2)==uShips(s));
            switch aisType
                case 1
                    shipTracksTemp.name = unique(msg13_char(s13idx,1));
                case 2
                    shipTracksTemp.name = unique(msg5_char(s5idx,1));
                case 3
                    shipTracksTemp.name = unique(msg13_char(s13idx,1));
                    s5idx = s13idx;
            end
            if isempty(shipTracksTemp.name)
                shipTracksTemp.name{1} = 'unknown';
            end
            fprintf('\t%s\n',shipTracksTemp.name{1});
            
            % sort times
            [timeStamps,timeIdx] = sort(msg13_num(s13idx,1));
            % decide if there are multiple passages of the same vessel.
            % by looking for gaps of >=30mins
            tDiff = diff(timeStamps);
            transitGaps = [0,find(tDiff>=(1/(24*4)))',length(timeStamps)];
            uTransits = length(transitGaps)-1;
            fprintf('\t\t%0.0f Passage(s) Found\n',uTransits);
%             if uTransits>5
%                 1;
%             end
            tStart = 1;
            thisShip_char_m5 = msg5_char(s5idx(timeIdx),:);
            thisShip_num_m13 = msg13_num(s13idx(timeIdx),:);
            thisShip_num_m5 = msg5_num(s5idx(timeIdx),:);
            
            for iT = 1:uTransits
                
                transitIdx = transitGaps(tStart)+1:transitGaps(tStart+1);
                [~,uTimes] = unique(thisShip_num_m13(transitIdx,1));
                shipTracks(sInc).dnums = thisShip_num_m13(transitIdx(uTimes),1);

                shipTracks(sInc).name = shipTracksTemp.name;
                shipTracks(sInc).shipType = unique(thisShip_char_m5(transitIdx(uTimes),2));
                shipTracks(sInc).MMSI = uShips(s);
                shipTracks(sInc).IMO = unique(thisShip_num_m5(transitIdx(uTimes),3));
                shipTracks(sInc).lons = thisShip_num_m13(transitIdx(uTimes),5);
                shipTracks(sInc).lats = thisShip_num_m13(transitIdx(uTimes),6);
                shipTracks(sInc).SOG = thisShip_num_m13(transitIdx(uTimes),4);
                shipTracks(sInc).COG = thisShip_num_m13(transitIdx(uTimes),7);
                shipTracks(sInc).trueHeading = thisShip_num_m13(transitIdx(uTimes),8);
                % voyage data - datenum, IMO, draught, dimensions ( toBow, toStern, toPort,
                % toStarboard )
                if aisType ~=3
                    shipTracks(sInc).vData = [ thisShip_num_m5(transitIdx(uTimes),1), thisShip_num_m5(transitIdx(uTimes),3:8) ];
                else
                    shipTracks(sInc).vData = [thisShip_num_m13(transitIdx(uTimes),1),thisShip_num_m5(transitIdx(uTimes),1),...
                        thisShip_num_m5(transitIdx(uTimes),2:6) ];
                end
             
                if plotOn
                    figure(101);clf
                    plot(shipTracks(sInc).lats,shipTracks(sInc).lons,'o')
                    hold on
                    plot(siteLatLon(1),siteLatLon(2),'ok')
                    hold off
                    1; 
                end
                
                tStart = tStart+1;
                sInc = sInc+1;
            end
        end
        save(offn,'shipTracks');
    else
        fprintf('No ships within bounds found\n');
    end
end

