# -----------------------------------------------------------------------------
# Archivo generado automaticamente para importar recursos existentes al tfstate.
# Generado: 2026-05-08 12:37:32
# StackType: foundation
# No editar manualmente salvo revision controlada.
# Borrar este fichero despues de materializar los imports en el state.
# -----------------------------------------------------------------------------

# oci_identity_tag_namespace | TAGNS-LZ-ROLE-KEY | o-p-om2-tagns-name-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["TAGNS-LZ-ROLE-KEY"]
  id = "ocid1.tagnamespace.oc19..aaaaaaaa6u3i3nhokejdygnepikolj7qp6647p3wum25s3dnpjtt7shlqzuq"
}

# oci_identity_tag | TAG-LZ-ROLE-KEY | o-p-om2-tagns-name-001/o-p-om2-tag-role-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-LZ-ROLE-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaa6u3i3nhokejdygnepikolj7qp6647p3wum25s3dnpjtt7shlqzuq/tags/o-p-om2-tag-role-001"
}

# oci_identity_tag_namespace | TAGNS-LZ-GOV-KEY | o-p-om2-tagns-gov-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["TAGNS-LZ-GOV-KEY"]
  id = "ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq"
}

# oci_identity_tag | TAG-GOV-TECHNICAL-OWNER-KEY | o-p-om2-tagns-gov-001/technical-owner
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-TECHNICAL-OWNER-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/technical-owner"
}

# oci_identity_tag | TAG-GOV-OPERATIONAL-OWNER-KEY | o-p-om2-tagns-gov-001/operational-owner
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-OPERATIONAL-OWNER-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/operational-owner"
}

# oci_identity_tag | TAG-GOV-DEPARTMENT-KEY | o-p-om2-tagns-gov-001/department
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-DEPARTMENT-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/department"
}

# oci_identity_tag | TAG-GOV-COST-CENTER-KEY | o-p-om2-tagns-gov-001/cost-center
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-COST-CENTER-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/cost-center"
}

# oci_identity_tag | TAG-GOV-APPLICATION-CODE-KEY | o-p-om2-tagns-gov-001/application-code
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-APPLICATION-CODE-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/application-code"
}

# oci_identity_tag | TAG-GOV-APPLICATION-NAME-KEY | o-p-om2-tagns-gov-001/application-name
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-APPLICATION-NAME-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/application-name"
}

# oci_identity_tag | TAG-GOV-NAME-KEY | o-p-om2-tagns-gov-001/name
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-NAME-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/name"
}

# oci_identity_tag | TAG-GOV-ENVIRONMENT-KEY | o-p-om2-tagns-gov-001/environment
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-ENVIRONMENT-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/environment"
}

# oci_identity_tag | TAG-GOV-IAC-KEY | o-p-om2-tagns-gov-001/iac
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-IAC-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/iac"
}

# oci_identity_tag | TAG-GOV-BUSINESS-CRITICALITY-KEY | o-p-om2-tagns-gov-001/business-criticality
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-GOV-BUSINESS-CRITICALITY-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaad5ahmm2hnmoesuyygljfkjt63buqrgxpirzs7dohpnmp7qo4jaiq/tags/business-criticality"
}

# oci_identity_tag_namespace | TAGNS-LZ-ENS-KEY | o-p-om2-tagns-ens-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag_namespace.these["TAGNS-LZ-ENS-KEY"]
  id = "ocid1.tagnamespace.oc19..aaaaaaaa3iliimrn4vxzbtpxutkshe52fu6qs4rbwcdnlvtxhcdybxgjzmeq"
}

# oci_identity_tag | TAG-ENS-AUTHENTICITY-KEY | o-p-om2-tagns-ens-001/ens-authenticity
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-ENS-AUTHENTICITY-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaa3iliimrn4vxzbtpxutkshe52fu6qs4rbwcdnlvtxhcdybxgjzmeq/tags/ens-authenticity"
}

# oci_identity_tag | TAG-ENS-INTEGRITY-KEY | o-p-om2-tagns-ens-001/ens-integrity
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-ENS-INTEGRITY-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaa3iliimrn4vxzbtpxutkshe52fu6qs4rbwcdnlvtxhcdybxgjzmeq/tags/ens-integrity"
}

# oci_identity_tag | TAG-ENS-AVAILABILITY-KEY | o-p-om2-tagns-ens-001/ens-availability
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-ENS-AVAILABILITY-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaa3iliimrn4vxzbtpxutkshe52fu6qs4rbwcdnlvtxhcdybxgjzmeq/tags/ens-availability"
}

# oci_identity_tag | TAG-ENS-CONFIDENTIALITY-KEY | o-p-om2-tagns-ens-001/ens-confidentiality
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-ENS-CONFIDENTIALITY-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaa3iliimrn4vxzbtpxutkshe52fu6qs4rbwcdnlvtxhcdybxgjzmeq/tags/ens-confidentiality"
}

# oci_identity_tag | TAG-ENS-TRACEABILITY-KEY | o-p-om2-tagns-ens-001/ens-traceability
import {
  to = module.oci_lz_orchestrator.module.oci_lz_tags[0].oci_identity_tag.these["TAG-ENS-TRACEABILITY-KEY"]
  id = "tagNamespaces/ocid1.tagnamespace.oc19..aaaaaaaa3iliimrn4vxzbtpxutkshe52fu6qs4rbwcdnlvtxhcdybxgjzmeq/tags/ens-traceability"
}

# oci_identity_compartment | CMP-LANDINGZONE-KEY | o-p-om2-cmp-land-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.these["CMP-LANDINGZONE-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaa43gu35rhrbtmirjlkxilrma3v5s2bqzhico4up6jvstnluiud3oa"
}

# oci_identity_compartment | CMP-LZ-NETWORK-KEY | o-p-om2-cmp-network-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_2["CMP-LZ-NETWORK-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaa5gtrrkqmob4ummcgl52exbo4d4vf55uvlzdku5j4fammf3b2pmlq"
}

# oci_identity_compartment | CMP-LZ-PLATFORM-KEY | o-p-om2-cmp-platform-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_2["CMP-LZ-PLATFORM-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaa6xwlxfjdyxcozp274vtvpp2ar5cahjmyljyxbb44wh726jjppm4q"
}

# oci_identity_compartment | CMP-LZ-EXACS-KEY | o-p-om2-cmp-exacs-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_3["CMP-LZ-EXACS-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaaexcetgujt75cw4hxoyttqpq5lqqfe4zcutegmvlk5vwikibcf3na"
}

# oci_identity_compartment | CMP-LZ-EXACS-DB-KEY | o-p-om2-cmp-exacsdb-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-EXACS-DB-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaaepzjuq4cjhkstzgva5nrliugyqgakoxjby5nudywy2ptpjc5jxaq"
}

# oci_identity_compartment | CMP-LZ-EXACS-INFRA-KEY | o-p-om2-cmp-exacsinfra-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-EXACS-INFRA-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaa2n4o2xmgt5b5auwg4ud6akdrdcnqqcrdmv6eiftlythr3ajhk7aa"
}

# oci_identity_compartment | CMP-LZ-LOGGING-KEY | o-p-om2-cmp-logg-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_3["CMP-LZ-LOGGING-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaaljtgrfd42d76gps36ryevoufbxk3cns7ri7zfwjvlauu4bq6r3na"
}

# oci_identity_compartment | CMP-LZ-DEVOPS-KEY | o-p-om2-cmp-devop-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_3["CMP-LZ-DEVOPS-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaapmdgp7bcad4vembnxe3t3iajxbpvztrlp3dk2p7y6xzwgnlbwslq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-KEY | o-p-om2-cmp-cdin-core-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_2["CMP-LZ-CDINSS-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaanalnmbuht65cel33bkqu2aowgdi3hvfcqofq2q7tsod5jcurxpxq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-PROD-KEY | o-p-om2-cmp-cdin-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_3["CMP-LZ-CDINSS-PROD-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaavug4kpn4sdoskxdzgkfi2uvke26grr6gbxtvg2f3x6ve3ngs5jfq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-PROD-NETWORK-KEY | o-p-om2-cmp-cdin-network-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-PROD-NETWORK-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaandgh7xjaze7etcofiogdw3vmeyeh73w6aj4aowtxynrr7hlla77a"
}

# oci_identity_compartment | CMP-LZ-CDINSS-PROD-PLATFORM-KEY | o-p-om2-cmp-cdin-platform-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-PROD-PLATFORM-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaatphkv6k4akaip3w5gvdauibjy5ag3p2hyhssgmfu5xgmivtykgha"
}

# oci_identity_compartment | CMP-LZ-CDINSS-PROD-PROJECTS-KEY | o-p-om2-cmp-cdin-projects-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-PROD-PROJECTS-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaag2d27gjmfsd36j45w7mi7piyfz6uvstpiuszd2gh2wto7kvmf5rq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-PROD-SECURITY-KEY | o-p-om2-cmp-cdin-security-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-PROD-SECURITY-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaakq3vum5nnnrkpl5ro7qt7qorb3a7p2nrwwdpzn7wzkbh3vwqa2dq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-NPR-KEY | o-d-om2-cmp-cdin-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_3["CMP-LZ-CDINSS-NPR-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaas5tb4msd3rlj6luy7smtqmnybp3cm4sprqoya3v4fbqvycpe6ewq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-NPR-NETWORK-KEY | o-d-om2-cmp-cdin-network-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-NPR-NETWORK-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaauvyilp65vl56pmzfvqqcv2dehlsykptzfbvliyrqwsqxmvsy3xcq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-NPR-PLATFORM-KEY | o-d-om2-cmp-cdin-platform-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-NPR-PLATFORM-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaa7ct5zrs6wj5uyr4ooofev5pnrzktmz3ut35kxajmr72olgw3eo5a"
}

# oci_identity_compartment | CMP-LZ-CDINSS-NPR-PROJECTS-KEY | o-d-om2-cmp-cdin-projects-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-NPR-PROJECTS-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaa5ve7hl23gcpq4s3imssn3z4sext3mncvmk3i43h3rjts4uaw45hq"
}

# oci_identity_compartment | CMP-LZ-CDINSS-NPR-SECURITY-KEY | o-d-om2-cmp-cdin-security-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_4["CMP-LZ-CDINSS-NPR-SECURITY-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaalzthcr6advj52mbrtu6h4viq523mko3gcyjc3nyppdu2ysxevqua"
}

# oci_identity_compartment | CMP-LZ-SECURITY-KEY | o-p-om2-cmp-security-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_compartments[0].oci_identity_compartment.level_2["CMP-LZ-SECURITY-KEY"]
  id = "ocid1.compartment.oc19..aaaaaaaayw5yjsj6mh5smp5piyjpjelequhd777a66psqqoxcw7czj4dyiua"
}

