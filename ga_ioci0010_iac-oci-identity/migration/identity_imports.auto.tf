# -----------------------------------------------------------------------------
# Archivo generado automaticamente para importar recursos existentes al tfstate.
# Generado: 2026-05-08 14:44:58
# StackType: identity
# No editar manualmente salvo revision controlada.
# Borrar este fichero despues de materializar los imports en el state.
# -----------------------------------------------------------------------------

# oci_identity_domain | COMMON-DOMAIN | o-p-om2-id-common-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domain.these["COMMON-DOMAIN"]
  id = "ocid1.domain.oc19..aaaaaaaaeuc6e6twowrhwgh6i4dxyp22x7g6mf4sf6x7kg7bbddovq6q33aa"
}

# oci_identity_domains_group | GRP-AUDITORS-ADMIN-KEY | o-p-om2-grp-admi-auditors-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-AUDITORS-ADMIN-KEY"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/fd59251e7ca84afbbd5276e6eb9fbc82"
}

# oci_identity_domains_group | GRP-COST-ADMIN-KEY | o-p-om2-grp-admi-costs-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-COST-ADMIN-KEY"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/7c6989c51bdf4e3b96efb129c2812166"
}

# oci_identity_domains_group | GRP-IAM-ADMIN-KEY | o-p-om2-grp-admi-iam-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-IAM-ADMIN-KEY"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/8db5d4ee2d4d4872ba1174f6f9d3a72b"
}

# oci_identity_domains_group | GRP-NETWORK-ADMIN-KEY | o-p-om2-grp-admi-network-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-NETWORK-ADMIN-KEY"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/1f2d88b9fb024af691e8993071ec3bc7"
}

# oci_identity_domains_group | GRP-SECURITY-ADMIN-KEY | o-p-om2-grp-admi-security-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-SECURITY-ADMIN-KEY"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/ee74da9199a543b9b01813e0d0f1df5a"
}

# oci_identity_domains_group | GRP-GLOBALSERV-ADMIN-KEY | o-p-om2-grp-admi-globalserv-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-GLOBALSERV-ADMIN-KEY"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/23ef3bf6cadb4c569054a54dba4eec97"
}

# oci_identity_domains_group | GRP-LZ-INFRA-ADMINS | o-p-om2-grp-admi-infra-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-LZ-INFRA-ADMINS"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/1f2d6edbbdba48de93f4fedd4c65173d"
}

# oci_identity_domains_group | GRP-LZ-DB-ADMINS | o-p-om2-grp-admi-database-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_identity_domains[0].oci_identity_domains_group.these["GRP-LZ-DB-ADMINS"]
  id = "idcsEndpoint/https://idcs-e0138a37daa84b4aacdb004b63eb5d75.eu-madrid-idcs-2.identity.oci.oraclecloud.eu:443/groups/32ed5ce0c1e94813aa968f24cc79d4b1"
}

# oci_identity_policy | PCY-AUDITING-ADMIN-KEY | o-p-om2-pcy-auda-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-AUDITING-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaabjxgam7szuyh4d5eo7qudjqw3guez4datmm5bbuztshg4kde6zeq"
}

# oci_identity_policy | PCY-COST-ADMIN-KEY | o-p-om2-pcy-costs-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-COST-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaa5dumus2g7hu5wzdhl5ldz6k4b3b3cwk6z3uawcvqps5y46nvoaiq"
}

# oci_identity_policy | PCY-GENERIC-ADMIN-KEY | o-p-om2-pcy-gadm-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-GENERIC-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaauuq6o2yznkigajumychulk7wji33rtqxj6poqmxyer25zhbaxnfa"
}

# oci_identity_policy | PCY-IAM-ADMIN-KEY | o-p-om2-pcy-iam-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-IAM-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaabmf4pp2dkjiimszoovt5szhe4odf5venihdww26pg7lgvr7l7hhq"
}

# oci_identity_policy | PCY-NETWORK-ADMIN-KEY | o-p-om2-pcy-nadm-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-NETWORK-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaau7hj5voz2en3kpe4yqdsydyxy2s6ocdxlptsup3vwugugvdvunva"
}

# oci_identity_policy | PCY-SECURITY-ADMIN-KEY | o-p-om2-pcy-secua-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-SECURITY-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaadw4yg722zptouzynqhvixgzor4elnceb3s2ezpgj3cpffgvafcsq"
}

# oci_identity_policy | PCY-GLOBALSERV-ADMIN-KEY | o-p-om2-pcy-globalserv-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-GLOBALSERV-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaanlp7wszhvfigqkbqqd7gcky4c2p6n4rpshpsgsakmjf5jlvd64xa"
}

# oci_identity_policy | PCY-SERVICES-ADMIN-KEY | o-p-om2-pcy-srva-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-SERVICES-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaayo4vgbniuac6igjmwzmp7jiyvbfcg4e2gvea6vmmdxjbgh2rezva"
}

# oci_identity_policy | PCY-LZ-PLATFORM-EXACS-GENERIC-ADMIN-KEY | o-p-om2-pcy-eadm-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-LZ-PLATFORM-EXACS-GENERIC-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaadzr3fb2ot5oxhthk3ns3kjeyitjob6qqq24wee2f2ofmejgqmjaa"
}

# oci_identity_policy | PCY-LZ-PLATFORM-EXACS-DB-ADMIN-KEY | o-p-om2-pcy-edb-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-LZ-PLATFORM-EXACS-DB-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaa6mkjpk4romgxowgqgwkzobk67ysco6bdmkfwcfotk6uy5w6fcwlq"
}

# oci_identity_policy | PCY-LZ-PLATFORM-EXACS-INFRA-ADMIN-KEY | o-p-om2-pcy-einf-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-LZ-PLATFORM-EXACS-INFRA-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaatvfyywb5ed64yslueu4wlpur4xnc2orplqrljaxsvwsatlszhqjq"
}

# oci_identity_policy | PCY-TENANCY-ADMIN-001-KEY | o-p-om2-pcy-tenantadmin-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-TENANCY-ADMIN-001-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaaaglw5a3wq2yysld6nvnepuizdp4adegscd6zbmpmceshlpypfrhq"
}

# oci_identity_policy | PCY-BILLING-VIEWER-KEY | o-p-om2-pcy-billv-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-BILLING-VIEWER-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaah4udlb2ei2g5s3ycqxhhneib5yi67glvfp3utxrerppe7rdofhkq"
}

# oci_identity_policy | PCY-VIEWER-KEY | o-p-om2-pcy-viewer-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-VIEWER-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaa3yiyiynuhe47chu5vpqme2hk2f5ry4q3ebks2m5dhkd34zu654va"
}

# oci_identity_policy | PCY-MONITORING-KEY | o-p-om2-pcy-monit-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-MONITORING-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaaj2kskvm4ewjukys4ek4cfmgygrccdtkqg64tdmhf5bltsr6xcyrq"
}

# oci_identity_policy | PCY-STORAGE-KEY | o-p-om2-pcy-stora-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-STORAGE-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaamoie5vsiedi32odiku54acf7u2j53xdibgqr7jobqd7ntgqwxhla"
}

# oci_identity_policy | PCY-OS-ADMIN-KEY | o-p-om2-pcy-osadm-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-OS-ADMIN-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaa3wd62tu3ysigprsk23oadqw77o5gfem5mkytkhq7qs7hc6zy7mya"
}

# oci_identity_policy | PCY-MARKETPLACE-KEY | o-p-om2-pcy-mktpl-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_policies[0].oci_identity_policy.these["PCY-MARKETPLACE-KEY"]
  id = "ocid1.policy.oc19..aaaaaaaajcg6iwjlvnnfojm3mgesto6bzbnj6pamzwwcrlbfedzoqjvc5gzq"
}

