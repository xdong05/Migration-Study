%% Constants and Parameters
clear, clc
v = 0.1; %volume of parcel, m^3
l = 100;
nt = 1:0.1:1000; % time (yrs)
dt = 0.1; %Timestep (yrs)
dx = 5;

kfbar = 1; %Dimensionless facilitation parameter (-)
kf = kfbar/dx; %Facilitation parameter (1/m)
kcbar = 1; %Dimensionless competition parameter (-)
kc = kcbar/dx; %Competition parameter (1/m)
D  = 0.2; % Mean annual rainfall (m)
Bt = 2.1; % Transpiration rate scaling factor (-)
Bb = 0.06; % Bare soil evaporation scaling factor (-)
Bv = 0.03; % Vegetation evaporation scaling factor (-)
te = 0.97; % Annual dry duration(yr)
tr = 1-te; % Annual wet duration (yr)
P = D/tr; %Precipitation rate (m/yr)
Kmax = 0.9*P; % Maximum hydraulic conductivity (m/yr)
K0 = 0.1*P; % Hydraulic conductivity in absence of vegetation (m/yr)
Kv = Kmax - K0; %Vegetated hydraulic conductivity (m/yr)
Tmax = Bt*D/te; %Maximum transpiration rate (m/yr)
Eb = Bb*D/te; % Evaporation at bare pixel 
Ev = Bv*D/te; % Evaporation rate at vegetated pixel 
bmax = 1; %maximum biomass (-)
Tcbar = 2; %Threshold transpiration rate for growth (-)
Tc = Tcbar*D/te; %Threshold transpiration rate (m/yr)
wcbar = 0.048; %(-) Dimensionless water threshold for plant growth
wc = wcbar*dx; %(m) threshold water for biomass growth in bare area
growth = 0.2; %(kg/m2-yr) biomass growth increment 
%% Create scene of vegetated (1) and bare(0) cells
b = [1 0 0;
     0 0 1;
     0 0 0];
 
p = 0.3.*ones(size(b,1),size(b,2));

%Create blank matrix for water balance components
Imat = zeros(size(b,1)*size(b,2),numel(nt));
Emat = zeros(size(b,1)*size(b,2),numel(nt));
Tmat = zeros(size(b,1)*size(b,2),numel(nt));
bmat = zeros(size(b,1)*size(b,2),numel(nt));
bvecmat = zeros(size(b,1)*size(b,2),numel(nt));

% Create blank matrix for water balance
w = zeros(size(b,1)*size(b,2),numel(nt));
x = randn(1,numel(b)); 
w(:,1) = abs(x)./max(abs(x));
%% For Loop for Governing Water Balance
for t=1:numel(nt);
    %% create b vector 
   bvec = zeros(size(b,1)*size(b,2),1);
   bvec(b ~= 0) = 1; %transform b into 1 and 0 matrix for use in Ei
   bvecmat(:,t) = bvec;
    %% Infitration, I
    I = zeros(size(b,1),size(b,2));
    runoff = zeros(size(b,1),size(b,2));
    for i = 2:size(b,1);
        I(i,:) = I(i-1,:) + v.*p(i,:).*(1-p(i,:)).^(i-1);
        runoff(i,:) = v+(v-I(i-1,:))-I(i,:);
    end
    
    I(1,:) = (v+runoff(end,:)).*(1-p(1,:));
    I = reshape(I,1,[]);
    
    Imat(:,t) = I; 
    %% Hydraulic Concuctivity, K and Transpiration,T
    
    %%%%% Ki
    % Create distance matrix
    [X,Y] = meshgrid(1:1:size(b,1));
    X = reshape(X,[],1);
    Y = reshape(Y,[],1);
    coordinates = horzcat(X,Y);
    r_mat = squareform(pdist(coordinates));
    
    gf = repmat(reshape(b,1,[]),size(b,1)^2,1);
    gf(gf > 0) = 1;
    gf(gf <= 0) = 0;
    
    gc = repmat(w(:,t),[1,size(w(:,t))]); 
    gc(gc > 0) = 1;
    gc(gc <=0) = 0;
    
    g_max = ones(size(b,1)^2);
    
    % Create f function to sum
    f_real_K = gf.*exp(-1*kf.^2.*(r_mat.^2));
    
    f_max_K = g_max.*exp(-1*kf.^2.*(r_mat.^2));
    f_max_vec_K = sum(f_max_K,2);
    f_max_mat_K = repmat(f_max_vec_K,1,size(b,1)^2);
    
    f_K = f_real_K./f_max_mat_K;
    sum_f_K = sum(f_K,2);
    
    % Calculate Ki from f and transform to original scene
    K = K0 + Kv.*(sum_f_K);
    %%K = vec2mat(K_vec,size(b,2))
   
    
    %%%%%% Ti 
    f_real_T = gc.*exp(-1*kc.^2.*(r_mat.^2));
    
    f_max_T = g_max.*exp(-1*kc.^2.*(r_mat.^2));
    f_max_vec_T = sum(f_max_T,2);
    f_max_mat_T = repmat(f_max_vec_T,1,size(b,1)^2);
    
    f_T = f_real_T./f_max_mat_T;
    sum_f_T = sum(f_T,1);
    
    % Calculate Ti from f and transform to original scene
    T = Tmax.*(sum_f_T);
    Tmat(:,t) = T;
    
    %%T = vec2mat(T_vec,size(b,2));
    %% Evaporation, Ei
    E = Ev.*bvec;
    indexE = find(bvec==0);
    E(indexE) = E(indexE) + Eb;
    Emat(:,t) = E;
    %% Biomass Growth
    indexkill = find(T<Tc);
    b(indexkill) = b(indexkill)-growth;
    indexgrowth = find(T>=Tc);
    b(indexgrowth) = b(indexgrowth)+growth;
    indexzero = find(b<0);
    b(indexzero) = 0;
   
    wmat = reshape(w(:,t),size(b,1),size(b,2));
    
    indexw = find(wmat>wc & b==0);
    b(indexw) = b(indexw) + growth;
    wmat(indexw) = wmat(indexw) - wc;
    w(:,t) = reshape(wmat,1,numel(wmat));
    
    b(b > 2) = 2;
    bmat(:,t) = reshape(b,1,[]);
    
    
    % Sum water balance and recreate biomass scene
    w(:,t+1) = w(:,t) + (Imat(:,t) - Emat(:,t)-Tmat(:,t))*dt;
   
    p = min((K./P),1);
    
    
end

