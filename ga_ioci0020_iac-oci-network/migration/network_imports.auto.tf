# -----------------------------------------------------------------------------
# Archivo generado automaticamente para importar recursos existentes al tfstate.
# Generado: 2026-05-11 12:08:27
# StackType: network
# No editar manualmente salvo revision controlada.
# Borrar este fichero despues de materializar los imports en el state.
# -----------------------------------------------------------------------------

# oci_core_drg | DRG-VLL-LZ-HUB-KEY | DRG-VLL-LZ-HUB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg.these["DRG-VLL-LZ-HUB-KEY"]
  id = "ocid1.drg.oc19.eu-madrid-2.aaaaaaaa7mto5domu4v7gk3bxq2rnlnslpdc2mnxlue7gatndpienpgmq5wa"
}

# oci_core_virtual_circuit | FCVC-VLL-LZ-HUB-001-KEY | o-p-om2-fas-connect-001
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_virtual_circuit.these["FCVC-VLL-LZ-HUB-001-KEY"]
  id = "ocid1.virtualcircuit.oc19.eu-madrid-2.amaaaaaapw27gbaanuzurkyeiybpbdq3rzledpyh2pfrfy3gdqxm5ahgpxqa"
}

# oci_core_virtual_circuit | FCVC-VLL-LZ-HUB-002-KEY | o-p-om2-fas-connect-002
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_virtual_circuit.these["FCVC-VLL-LZ-HUB-002-KEY"]
  id = "ocid1.virtualcircuit.oc19.eu-madrid-2.amaaaaaapw27gbaaao7b23y5cy6gvtype4l2xgjsv2xb2r6ekbqpi3jxuzra"
}

# oci_core_drg_route_distribution | DRGRD-VLL-LZ-HUB-KEY | DRGRD-VLL-LZ-HUB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_route_distribution.these["DRGRD-VLL-LZ-HUB-KEY"]
  id = "ocid1.drgroutedistribution.oc19.eu-madrid-2.aaaaaaaazwzwsiygf2o2topuugf27l4vaqv44eumhaqpekx7levcokk2uaja"
}

# oci_core_drg_route_table | DRGRT-VLL-LZ-HUB-KEY | DRGRT-VLL-LZ-HUB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_route_table.these["DRGRT-VLL-LZ-HUB-KEY"]
  id = "ocid1.drgroutetable.oc19.eu-madrid-2.aaaaaaaagrypb4d6mrlafpq5de6uukf2ytbdppaprzayjty2ur2zkwjvtc3q"
}

# oci_core_drg_route_table | DRGRT-VLL-LZ-SPOKES-KEY | DRGRT-VLL-LZ-SPOKES-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_route_table.these["DRGRT-VLL-LZ-SPOKES-KEY"]
  id = "ocid1.drgroutetable.oc19.eu-madrid-2.aaaaaaaaty742znqtrv7jvixwrldirgntsxk6kvrnuoqzkluxfrpe4nib3ja"
}

# oci_core_nat_gateway | NGW-VLL-LZ-HUB-KEY | NGW-VLL-LZ-HUB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_nat_gateway.these["NGW-VLL-LZ-HUB-KEY"]
  id = "ocid1.natgateway.oc19.eu-madrid-2.aaaaaaaanu7fddyxgdcchizzlez6bbfeomnnwrffuasiou7dpm7aem4fwmwa"
}

# oci_core_network_security_group | NSG-VLL-LZ-HUB-FW-KEY | NSG-VLL-LZ-HUB-FW-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group.these["NSG-VLL-LZ-HUB-FW-KEY"]
  id = "ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa5xxr7iqsclnzmnuo67fi2tvkwt6dcbxvunm5iidssolqfiifhmka"
}

# oci_core_network_security_group | NSG-VLL-LZ-HUB-LB-KEY | NSG-VLL-LZ-HUB-LB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group.these["NSG-VLL-LZ-HUB-LB-KEY"]
  id = "ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa7t76tg6awptn6iw2flr7jqtf5ut6n7y3rvcjk4cxknm6evfl2yea"
}

# oci_core_network_security_group_security_rule | NSG-VLL-LZ-HUB-FW-KEY.anywhere | NSG-VLL-LZ-HUB-FW-KEY.anywhere
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group_security_rule.egress["NSG-VLL-LZ-HUB-FW-KEY.anywhere"]
  id = "networkSecurityGroups/ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa5xxr7iqsclnzmnuo67fi2tvkwt6dcbxvunm5iidssolqfiifhmka/securityRules/7D5DE8"
}

# oci_core_network_security_group_security_rule | NSG-VLL-LZ-HUB-FW-KEY.to_lb | NSG-VLL-LZ-HUB-FW-KEY.to_lb
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group_security_rule.egress["NSG-VLL-LZ-HUB-FW-KEY.to_lb"]
  id = "networkSecurityGroups/ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa5xxr7iqsclnzmnuo67fi2tvkwt6dcbxvunm5iidssolqfiifhmka/securityRules/CE333E"
}

# oci_core_network_security_group_security_rule | NSG-VLL-LZ-HUB-LB-KEY.anywhere | NSG-VLL-LZ-HUB-LB-KEY.anywhere
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group_security_rule.egress["NSG-VLL-LZ-HUB-LB-KEY.anywhere"]
  id = "networkSecurityGroups/ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa7t76tg6awptn6iw2flr7jqtf5ut6n7y3rvcjk4cxknm6evfl2yea/securityRules/3C8E41"
}

# oci_core_network_security_group_security_rule | NSG-VLL-LZ-HUB-FW-KEY.from_lb | NSG-VLL-LZ-HUB-FW-KEY.from_lb
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group_security_rule.ingress["NSG-VLL-LZ-HUB-FW-KEY.from_lb"]
  id = "networkSecurityGroups/ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa5xxr7iqsclnzmnuo67fi2tvkwt6dcbxvunm5iidssolqfiifhmka/securityRules/CF899D"
}

# oci_core_network_security_group_security_rule | NSG-VLL-LZ-HUB-LB-KEY.http_443 | NSG-VLL-LZ-HUB-LB-KEY.http_443
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group_security_rule.ingress["NSG-VLL-LZ-HUB-LB-KEY.http_443"]
  id = "networkSecurityGroups/ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa7t76tg6awptn6iw2flr7jqtf5ut6n7y3rvcjk4cxknm6evfl2yea/securityRules/F43365"
}

# oci_core_network_security_group_security_rule | NSG-VLL-LZ-HUB-LB-KEY.http_80 | NSG-VLL-LZ-HUB-LB-KEY.http_80
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_network_security_group_security_rule.ingress["NSG-VLL-LZ-HUB-LB-KEY.http_80"]
  id = "networkSecurityGroups/ocid1.networksecuritygroup.oc19.eu-madrid-2.aaaaaaaa7t76tg6awptn6iw2flr7jqtf5ut6n7y3rvcjk4cxknm6evfl2yea/securityRules/6ECC18"
}

# oci_core_route_table | RT-VLL-LZ-HUB-INGRESS-KEY | RT-VLL-LZ-HUB-INGRESS-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.igw_natgw_specific_route_tables["RT-VLL-LZ-HUB-INGRESS-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaa7rjao6irht6lazfqd3slojdxok4yqdyl62f6wnfqg2knnuv62qta"
}

# oci_core_route_table | RT-VLL-LZ-HUB-NATGW-KEY | RT-VLL-LZ-HUB-NATGW-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.igw_natgw_specific_route_tables["RT-VLL-LZ-HUB-NATGW-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaa7qnu4kwqdf6p7vt3ert6n6xyivqmavhegslyazq3nuna6zawzida"
}

# oci_core_route_table | RT-VLL-LZ-HUB-MGMT-KEY | RT-VLL-LZ-HUB-MGMT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.lpg_specific_route_tables["RT-VLL-LZ-HUB-MGMT-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaaplxulbv5ftsmxk3t23zaqo6zbest5cc7epsnx3l5i7k2g6geivbq"
}

# oci_core_route_table | RT-VLL-LZ-EXACS-NPR-BACKUP-KEY | RT-VLL-LZ-EXACS-NPR-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.non_gw_specific_remaining_route_tables["RT-VLL-LZ-EXACS-NPR-BACKUP-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaaxj3cpw5v7ck6pshlzysnpxep73cvbfv6wunmzcxesun4ewxnmkxa"
}

# oci_core_route_table | RT-VLL-LZ-EXACS-NPR-CLIENT-KEY | RT-VLL-LZ-EXACS-NPR-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.non_gw_specific_remaining_route_tables["RT-VLL-LZ-EXACS-NPR-CLIENT-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaa26d4p6ngnmfwyddmi7ayygbwkypfgw5sxh4wb7kznmfuparwdwjq"
}

# oci_core_route_table | RT-VLL-LZ-EXACS-PRO-BACKUP-KEY | RT-VLL-LZ-EXACS-PRO-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.non_gw_specific_remaining_route_tables["RT-VLL-LZ-EXACS-PRO-BACKUP-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaalajl2baakfooxs77yvz6qt3ybptz6vxrc3fapjnc37i53ijhywqa"
}

# oci_core_route_table | RT-VLL-LZ-EXACS-PRO-CLIENT-KEY | RT-VLL-LZ-EXACS-PRO-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.non_gw_specific_remaining_route_tables["RT-VLL-LZ-EXACS-PRO-CLIENT-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaavysyvwdx5ejpjsmd5jxgvjam6oiflmsiidryhomite4ennv5enfq"
}

# oci_core_route_table | RT-VLL-LZ-HUB-FW-KEY | RT-VLL-LZ-HUB-FW-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table.non_gw_specific_remaining_route_tables["RT-VLL-LZ-HUB-FW-KEY"]
  id = "ocid1.routetable.oc19.eu-madrid-2.aaaaaaaamhwcecichg7l26fnd2rgvqk7ni5x2worom4hblpff3oax6fwie4a"
}

# oci_core_route_table_attachment | SN-VLL-LZ-EXACS-NPR-BACKUP-KEY | SN-VLL-LZ-EXACS-NPR-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-EXACS-NPR-BACKUP-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaapzxknvaxdzhxhy6bnelwuyqykfwccruyrftnshskkcc2upjphvka/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaaxj3cpw5v7ck6pshlzysnpxep73cvbfv6wunmzcxesun4ewxnmkxa"
}

# oci_core_route_table_attachment | SN-VLL-LZ-EXACS-NPR-CLIENT-KEY | SN-VLL-LZ-EXACS-NPR-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-EXACS-NPR-CLIENT-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaakekfuzcbd43hvuufgzx6x5uybwjcst35azjilncmjgc254i22gpa/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaa26d4p6ngnmfwyddmi7ayygbwkypfgw5sxh4wb7kznmfuparwdwjq"
}

# oci_core_route_table_attachment | SN-VLL-LZ-EXACS-PRO-BACKUP-KEY | SN-VLL-LZ-EXACS-PRO-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-EXACS-PRO-BACKUP-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaakmjkmcwkvu6a3aq4izcvnpsqlgcac7aivh55zn7p4bg22xvwdw4q/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaalajl2baakfooxs77yvz6qt3ybptz6vxrc3fapjnc37i53ijhywqa"
}

# oci_core_route_table_attachment | SN-VLL-LZ-EXACS-PRO-CLIENT-KEY | SN-VLL-LZ-EXACS-PRO-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-EXACS-PRO-CLIENT-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaa25at3fn2vvtxylgqpchpy6lwgcerzodsg3sc53qctppm7fqaddzq/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaavysyvwdx5ejpjsmd5jxgvjam6oiflmsiidryhomite4ennv5enfq"
}

# oci_core_route_table_attachment | SN-VLL-LZ-HUB-DNS | SN-VLL-LZ-HUB-DNS
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-HUB-DNS"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaana6o4ztydw3u3i7f4nv4xkmmjkscvdj6aiv5t6wnuxqlcfrjp3bq/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaaplxulbv5ftsmxk3t23zaqo6zbest5cc7epsnx3l5i7k2g6geivbq"
}

# oci_core_route_table_attachment | SN-VLL-LZ-HUB-FW-KEY | SN-VLL-LZ-HUB-FW-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-HUB-FW-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaayg3uwvlk4sppnxnqwcqgwcw4egv3b2uwdim36mjqg7gzfvfvzmda/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaamhwcecichg7l26fnd2rgvqk7ni5x2worom4hblpff3oax6fwie4a"
}

# oci_core_route_table_attachment | SN-VLL-LZ-HUB-MGMT-KEY | SN-VLL-LZ-HUB-MGMT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-HUB-MGMT-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaavcjg6zczpbp4h2avcsawctp2su5x6nbzsfeqizy5edgy7b2chwxa/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaaplxulbv5ftsmxk3t23zaqo6zbest5cc7epsnx3l5i7k2g6geivbq"
}

# oci_core_route_table_attachment | SN-VLL-LZ-HUB-MON-KEY | SN-VLL-LZ-HUB-MON-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_route_table_attachment.these["SN-VLL-LZ-HUB-MON-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaay4uhy4psi4rga5wpyz2ciq4ev4bw6ijmgjqqwj5at77l77xx6yhq/ocid1.routetable.oc19.eu-madrid-2.aaaaaaaaplxulbv5ftsmxk3t23zaqo6zbest5cc7epsnx3l5i7k2g6geivbq"
}

# oci_core_security_list | SL-VLL-LZ-EXACS-NPR-BACKUP-KEY | SL-VLL-LZ-EXACS-NPR-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_security_list.these["SL-VLL-LZ-EXACS-NPR-BACKUP-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaaq3gxlqmzhihavo2fq4ftdt4lh2nwcvngfneo4oj6ihx7sjaetiiq"
}

# oci_core_security_list | SL-VLL-LZ-EXACS-NPR-CLIENT-KEY | SL-VLL-LZ-EXACS-NPR-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_security_list.these["SL-VLL-LZ-EXACS-NPR-CLIENT-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaaj3ondyeq6escsvhcprydlvvdrc36vjgnx5q3gdw2bitgtpf2sctq"
}

# oci_core_security_list | SL-VLL-LZ-EXACS-PRO-BACKUP-KEY | SL-VLL-LZ-EXACS-PRO-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_security_list.these["SL-VLL-LZ-EXACS-PRO-BACKUP-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaa52gfgvniilio5mgu475f5k2bjfbnoaslvbvvnhfwwm4ztheyd7ua"
}

# oci_core_security_list | SL-VLL-LZ-EXACS-PRO-CLIENT-KEY | SL-VLL-LZ-EXACS-PRO-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_security_list.these["SL-VLL-LZ-EXACS-PRO-CLIENT-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaa5a3rinjqw7rsclpltq5hh64ec7gldm5jocgm2h2u2scjdvxoj7fq"
}

# oci_core_security_list | SL-VLL-LZ-HUB-FW-KEY | SL-VLL-LZ-HUB-FW-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_security_list.these["SL-VLL-LZ-HUB-FW-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaacnodbu3y73ugby74ryrr7c5aoa2pzwdryyyoenq2frlckcoedj3a"
}

# oci_core_security_list | SL-VLL-LZ-HUB-MGMT-KEY | SL-VLL-LZ-HUB-MGMT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_security_list.these["SL-VLL-LZ-HUB-MGMT-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaax4r77poacckw7t2nmbxddnkqmrxeh3sbdys6tbm2voyrtumnnbuq"
}

# oci_core_service_gateway | SGW-VLL-LZ-EXACS-NPR-KEY | SGW-VLL-LZ-EXACS-NPR-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_service_gateway.these["SGW-VLL-LZ-EXACS-NPR-KEY"]
  id = "ocid1.servicegateway.oc19.eu-madrid-2.aaaaaaaa3gxhavba3sykmzt2reypnwomdrcozlkmixnpu2elhenu5u6oripa"
}

# oci_core_service_gateway | SGW-VLL-LZ-EXACS-PRO-KEY | SGW-VLL-LZ-EXACS-PRO-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_service_gateway.these["SGW-VLL-LZ-EXACS-PRO-KEY"]
  id = "ocid1.servicegateway.oc19.eu-madrid-2.aaaaaaaavxjuqe7azfv344j6xgkbhuk2u5j6az5ndjzmrljhupocmfpejm7a"
}

# oci_core_service_gateway | SGW-VLL-LZ-HUB-KEY | SGW-VLL-LZ-HUB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_service_gateway.these["SGW-VLL-LZ-HUB-KEY"]
  id = "ocid1.servicegateway.oc19.eu-madrid-2.aaaaaaaao3zwviqb3hw7jylshx4zk4bbsyoipquitxuh5qu3xkkyx6uutjua"
}

# oci_core_subnet | SN-VLL-LZ-EXACS-NPR-BACKUP-KEY | SN-VLL-LZ-EXACS-NPR-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-EXACS-NPR-BACKUP-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaapzxknvaxdzhxhy6bnelwuyqykfwccruyrftnshskkcc2upjphvka"
}

# oci_core_subnet | SN-VLL-LZ-EXACS-NPR-CLIENT-KEY | SN-VLL-LZ-EXACS-NPR-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-EXACS-NPR-CLIENT-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaakekfuzcbd43hvuufgzx6x5uybwjcst35azjilncmjgc254i22gpa"
}

# oci_core_subnet | SN-VLL-LZ-EXACS-PRO-BACKUP-KEY | SN-VLL-LZ-EXACS-PRO-BACKUP-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-EXACS-PRO-BACKUP-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaakmjkmcwkvu6a3aq4izcvnpsqlgcac7aivh55zn7p4bg22xvwdw4q"
}

# oci_core_subnet | SN-VLL-LZ-EXACS-PRO-CLIENT-KEY | SN-VLL-LZ-EXACS-PRO-CLIENT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-EXACS-PRO-CLIENT-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaa25at3fn2vvtxylgqpchpy6lwgcerzodsg3sc53qctppm7fqaddzq"
}

# oci_core_subnet | SN-VLL-LZ-HUB-DNS | SN-VLL-LZ-HUB-DNS
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-HUB-DNS"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaana6o4ztydw3u3i7f4nv4xkmmjkscvdj6aiv5t6wnuxqlcfrjp3bq"
}

# oci_core_subnet | SN-VLL-LZ-HUB-FW-KEY | SN-VLL-LZ-HUB-FW-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-HUB-FW-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaayg3uwvlk4sppnxnqwcqgwcw4egv3b2uwdim36mjqg7gzfvfvzmda"
}

# oci_core_subnet | SN-VLL-LZ-HUB-MGMT-KEY | SN-VLL-LZ-HUB-MGMT-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-HUB-MGMT-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaavcjg6zczpbp4h2avcsawctp2su5x6nbzsfeqizy5edgy7b2chwxa"
}

# oci_core_subnet | SN-VLL-LZ-HUB-MON-KEY | SN-VLL-LZ-HUB-MON-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_subnet.these["SN-VLL-LZ-HUB-MON-KEY"]
  id = "ocid1.subnet.oc19.eu-madrid-2.aaaaaaaay4uhy4psi4rga5wpyz2ciq4ev4bw6ijmgjqqwj5at77l77xx6yhq"
}

# oci_core_vcn | VCN-VLL-LZ-EXACS-NPR-KEY | VCN-VLL-LZ-EXACS-NPR-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_vcn.these["VCN-VLL-LZ-EXACS-NPR-KEY"]
  id = "ocid1.vcn.oc19.eu-madrid-2.amaaaaaapw27gbaatri7xmitendke5zbqpwk3dzghwa7apab56eya5rb2fza"
}

# oci_core_vcn | VCN-VLL-LZ-EXACS-PRO-KEY | VCN-VLL-LZ-EXACS-PRO-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_vcn.these["VCN-VLL-LZ-EXACS-PRO-KEY"]
  id = "ocid1.vcn.oc19.eu-madrid-2.amaaaaaapw27gbaa26l4e3e3jodcwszp52idisn7ntkehkfskz3zzbp7eliq"
}

# oci_core_vcn | VCN-VLL-LZ-HUB-KEY | VCN-VLL-LZ-HUB-KEY
import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_vcn.these["VCN-VLL-LZ-HUB-KEY"]
  id = "ocid1.vcn.oc19.eu-madrid-2.amaaaaaapw27gbaahaampmaqpuconyvwmecndp6epapf6uv4p2okvyd2qe4q"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_attachment.these["DRGATT-VLL-LZ-HUB-VCN-KEY"]
  id = "ocid1.drgattachment.oc19.eu-madrid-2.aaaaaaaau5svtwnjv7cxgsdkjvf7qci5weqczdxvyfsn64vzf7hjrzdzsmva"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_attachment.these["DRGATT-VLL-LZ-EXACS-PRO-VCN-KEY"]
  id = "ocid1.drgattachment.oc19.eu-madrid-2.aaaaaaaaj33nwa5zf5dtjjbalee7p6eigxki26bmxpqejenw77q2u6secvaq"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_attachment.these["DRGATT-VLL-LZ-EXACS-NPR-VCN-KEY"]
  id = "ocid1.drgattachment.oc19.eu-madrid-2.aaaaaaaapbha2jrstqqnvl4hq3zvk35jq5m56vufoznlphbdgqonuygo4bfa"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_default_security_list.these["CUSTOM-DEFAULT-SEC-LIST-VCN-VLL-LZ-EXACS-NPR-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaa4jrnotramft6warg26vgbevq65zihdr5lw55dyhuqouuniphifqa"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_default_security_list.these["CUSTOM-DEFAULT-SEC-LIST-VCN-VLL-LZ-EXACS-PRO-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaam7bfpsyqjshbavhxef26hprqbywe6gbkbdpujtylf3mut5v6jtza"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_default_security_list.these["CUSTOM-DEFAULT-SEC-LIST-VCN-VLL-LZ-HUB-KEY"]
  id = "ocid1.securitylist.oc19.eu-madrid-2.aaaaaaaat22ufnlfb5ss4hzw6j5cl7s34itv7uzvgiidxorwkoqlzzde6zcq"
}

import {
  to = module.oci_lz_orchestrator.module.oci_lz_network[0].oci_core_drg_route_table_route_rule.these["DRGRT-VLL-LZ-SPOKES-STATIC-ROUTE"]
  id = "drgRouteTables/ocid1.drgroutetable.oc19.eu-madrid-2.aaaaaaaaty742znqtrv7jvixwrldirgntsxk6kvrnuoqzkluxfrpe4nib3ja/routeRules/5554"
}
