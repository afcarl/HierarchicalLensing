functions {
  vector nfw(vector r, real m200, real c200, real zl, real zs, real dl, real ds, real dls) {
    real c;
    real Mpc;
    real pc;
    real cMpc;
    real Msun;
    real G;
    real GMsunMpc;
    real h;
    real H0;
    real Om;
    real Ol;
    real Ez;
    real rho_crit;
    real sigma_crit;
    real rho200;
    real r200;
    real rs;
    real rhos;

    vector[dims(r)[1]] shear;

    c = 2.99792e5; // km / s
    Mpc = 3.0856e19; // km
    pc = Mpc / 1e6 * 1e3; // m
    cMpc = c/Mpc; // Mpc / s

    Msun = 1.989e30; // kg
    

    G = 6.672e-11; // m^3 / kg / s^2
    GMsunMpc = G / (pc*pc*pc) * 1e-18 * Msun; // Mpc^3 / MSun / s^2

    h = 0.7;
    H0 = h * 100.0;
    Om = 0.28;
    Ol = 0.72;

    Ez = sqrt(Om*(1.0 + zl)^3 + Ol);

    rho_crit = 3.0*((H0*Ez/Mpc)^2)/(8.0*pi()*GMsunMpc);

    sigma_crit = cMpc^2*ds/(4.0*GMsunMpc*pi()*dl*dls);

    rho200 = 200.0*rho_crit;
    r200 = (3.0*m200/(4.0*pi()*rho200))^(1.0/3.0);

    rs = r200 / c200;
    rhos = (rho200*c200^3)/(3.0*(log1p(c200) - c200/(1.0+c200)));

    for (i in 1:dims(r)[1]) {
      real tan_term;
      real denom_term;
      real term;
      real sigma;
      real mean_sigma;
      real rhoNFW;
      real kappaNFW;
      real meankappaNFW;
      real gammaNFW;
      real ri;

      ri = r[i];

      tan_term = (1.0 - ri/rs)/(1.0 + ri/rs);
      denom_term = 1.0 - (ri/rs)*(ri/rs);

      if (tan_term > 0 && denom_term > 0) {
        term = 2.0*atanh(sqrt(tan_term))/sqrt(denom_term);
      } else if (tan_term < 0 && denom_term < 0) {
        term = 2.0*atan(sqrt(-tan_term))/sqrt(-denom_term);
      } else {
        // We are *very* close to ri == rs; this is a third-order
        // power series expansion.
        real x;
        x = ri/rs - 1.0;
        term = 1.0 + x*(-2.0/3.0 + x*(7.0/5.0 + x*(-12.0/35.0)));
      }

      sigma = 2*rs*rhos*(1.0-term)/(ri*ri/rs/rs - 1.0);
      mean_sigma = 4.0*rs*rhos*(term + log(ri/rs/2.0))/(ri*ri/rs/rs);
      rhoNFW = rhos/(ri/rs*(1.0 + ri/rs)^2);
      kappaNFW = sigma / sigma_crit;
      meankappaNFW = mean_sigma / sigma_crit;
      gammaNFW = meankappaNFW - kappaNFW;
      shear[i] = fabs(gammaNFW/(1.0 - kappaNFW));

      if (is_nan(shear[i])) {
	reject("shear is nan at radius ", ri, " M200 is ", m200, " c is ", c200);
      }
    }

    return shear;
  }
}

data {
  int nr;

  vector[nr] rs;
  vector[nr] kappas;
  vector[nr] sigma_kappas;

  real zl;
  real zs;
  real dl;
  real ds;
  real dls;
}

parameters {
  real<lower=log(1e12), upper=log(1e16)> logM;
  real<lower=log(1), upper=log(10)> logC;
}

transformed parameters {
  vector[nr] model_kappas;
  real M;
  real C;

  M = exp(logM);
  C = exp(logC);
  
  model_kappas = nfw(rs, M, C, zl, zs, dl, ds, dls);
}

model {
  // Flat-in-log prior on M and C
  kappas ~ normal(model_kappas, sigma_kappas);
}
