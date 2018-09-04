% Store png images into mat file that will be used by the quickfit.UI code

d = dir('*.png');

s = struct();

for i = 1:length(d)
    im = imread(d(i).name);
    bg = im(:,:,1)==255 & im(:,:,2)==0 & im(:,:,3)==0;
    im = double(im)/255;
    im(repmat(bg,[1 1 3])) = nan;
    [a,b,c]=fileparts(d(i).name);
    s.(b) = im;
end
size(s)
save('toolbarimgs','-struct','s');