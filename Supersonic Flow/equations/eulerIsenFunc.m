function [fvOUT, waveSpd] = eulerIsenFunc(GR, FL, BC, EE)

% Get Indexing
indP1 = reshape(strcmp(BC.N.varType, 'v1'),1,1,size(EE,3));
indP2 = reshape(strcmp(BC.N.varType, 'v2'),1,1,size(EE,3));
indRho = reshape(strcmp(BC.N.varType, 's'),1,1,size(EE,3));

if GR.isPolar
    % Pressure Calculation
    PP = (EE(:,:,indRho).^FL.gam)./(FL.gam .* FL.M0.^2);

    % Boundary Calculation -> include pressure terms
    bcN = bcCalc(GR,BC,EE,'N') .* bcCalc(GR,BC,EE,'N',indP1) ./ bcCalc(GR,BC,EE,'N',indRho);bcNP = indP1.*(bcCalc(GR,BC,EE,'N',indRho).^(FL.gam))./(FL.gam.*FL.M0.^2);
    bcS = bcCalc(GR,BC,EE,'S') .* bcCalc(GR,BC,EE,'S',indP1) ./ bcCalc(GR,BC,EE,'S',indRho);bcSP = indP1.*(bcCalc(GR,BC,EE,'S',indRho).^(FL.gam))./(FL.gam.*FL.M0.^2);
    bcE = bcCalc(GR,BC,EE,'E') .* bcCalc(GR,BC,EE,'E',indP2) ./ bcCalc(GR,BC,EE,'E',indRho);bcEP = indP2.*(bcCalc(GR,BC,EE,'E',indRho).^(FL.gam))./(FL.gam.*FL.M0.^2);
    bcW = bcCalc(GR,BC,EE,'W') .* bcCalc(GR,BC,EE,'W',indP2) ./ bcCalc(GR,BC,EE,'W',indRho);bcWP = indP2.*(bcCalc(GR,BC,EE,'W',indRho).^(FL.gam))./(FL.gam.*FL.M0.^2);

    % Calculate Wave Terms (Conservation Form)
    FF = EE.*EE(:,:,indP2)./EE(:,:,indRho);% + indP2.*PP;
    GG = EE.*EE(:,:,indP1)./EE(:,:,indRho);% + indP1.*PP;
    
    GG = GG.*GR.RR;
    %FF = FF + indP2.*PP;
    % radial derivatives must calculate pressure and vel. separately!
    GG_1 =  ([GG(2:end,:,:);(GR.RR(end,:)+GR.dR).*bcN] - [(GR.RR(1,:)-0.5.*GR.dR).*bcS;GG(1:end-1,:,:)])./(2.*GR.dR.*GR.RR); ... % vector Flux
%     PP_1 =  ([indP1.*PP(2:end,:);bcNP] - [bcSP;indP1.*PP(1:end-1,:)])./(2*GR.dR);...Pressure Term
    PP_1 =  ([indP1.*PP(2:end,:);bcNP] - [indP1.*(PP(1,:) - GR.dR.*FF(1,:,indP2)./GR.r_cyl);indP1.*PP(1:end-1,:)])./(2*GR.dR);...Pressure Term
    C_1 =  -indP1.*(EE(:,:,indP2).^2)./(GR.RR.*EE(:,:,indRho)); ... Centrifugal Term
%     FF_2 =  ([FF(:,2:end,:),bcE+bcEP] - [bcW+bcWP,FF(:,1:end-1,:)])./(2.*GR.dT.*GR.RR)...
    FF_2 =  ([FF(:,2:end,:),bcE] - [bcW,FF(:,1:end-1,:)])./(2.*GR.dT.*GR.RR);...
    PP_2 = ([indP2.*PP(:,2:end),bcEP] - [bcWP,indP2.*PP(:,1:end-1)])./(2.*GR.dT.*GR.RR);
    C_2 = indP2.*EE(:,:,indP1).*EE(:,:,indP2)./(EE(:,:,indRho).*GR.RR);

    fvOUT = FF_2 + GG_1 + PP_1 + PP_2 + C_1 + C_2;
else
    EEx = [bcCalc(GR,FL,BC,EE,'W'), EE, bcCalc(GR,FL,BC,EE,'E')];
    EEy = [bcCalc(GR,FL,BC,EE,'S'); EE; bcCalc(GR,FL,BC,EE,'N')];
    
    FF = indRho.*EEx(:,:,indP2) + indP2.*(EEx(:,:,indP2).^2./EEx(:,:,indRho) + (EEx(:,:,indRho).^FL.gam)./(FL.gam.*FL.M0^2)) + indP1.*(EEx(:,:,indP1).*EEx(:,:,indP2)./EEx(:,:,indRho));
    GG = indRho.*EEy(:,:,indP1) + indP1.*(EEy(:,:,indP1).^2./EEy(:,:,indRho) + (EEy(:,:,indRho).^FL.gam)./(FL.gam.*FL.M0^2)) + indP2.*(EEy(:,:,indP1).*EEy(:,:,indP2)./EEy(:,:,indRho));
    FF_2 = (FF(:,3:end,:) - FF(:,1:end-2,:))./(2.*GR.dx);
    GG_1 = (GG(3:end,:,:) - GG(1:end-2,:,:))./(2.*GR.dy);
    fvOUT = FF_2 + GG_1;
end

V2 = EE(:,:,indP2)./EE(:,:,indRho);%./GR.RR;
V1 = EE(:,:,indP1)./EE(:,:,indRho);%./GR.RR;
V_C = sqrt((EE(:,:,indRho).^(FL.gam-1))./(FL.M0.^2));
V2 = max(cat(3, abs(V2+V_C), abs(V2), abs(V2-V_C)),[],3);
V1 = max(cat(3, abs(V1+V_C), abs(V1), abs(V1-V_C)),[],3);
waveSpd = [max(abs(V2(:))), max(abs(V1(:)))];

end