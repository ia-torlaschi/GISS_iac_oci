# Imports declarativos v3.7 para FastConnect ya existente en OCI
# Objetivo: evitar recreacion de virtual circuits al ejecutar plan/apply en monolitico.

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_virtual_circuit.these["FCVC-VLL-LZ-HUB-001-KEY"]
  id = "ocid1.virtualcircuit.oc19.eu-madrid-2.amaaaaaapw27gbaanuzurkyeiybpbdq3rzledpyh2pfrfy3gdqxm5ahgpxqa"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_virtual_circuit.these["FCVC-VLL-LZ-HUB-002-KEY"]
  id = "ocid1.virtualcircuit.oc19.eu-madrid-2.amaaaaaapw27gbaaao7b23y5cy6gvtype4l2xgjsv2xb2r6ekbqpi3jxuzra"
}
