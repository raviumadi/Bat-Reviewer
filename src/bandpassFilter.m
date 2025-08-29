% bandpass filter signal between hp and lp Hz
% [fsig] = bandpassFilter(sig, hp, lp, r, fs)
function [fsig] = bandpassFilter(sig, hp, lp, r, fs)
[bpb, bpa] = butter(r,[2*hp/fs 2*lp/fs]);
fsig = zeros(size(sig));
for i = 1:size(sig,2)
    fsig(:,i) = filter(bpb,bpa, sig(:,i));% substituted from filtfilt 08.09.22
end 
