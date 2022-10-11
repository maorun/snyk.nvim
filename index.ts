import {
  CloudConfigFileTypes,
  issuesToLineNumbers,
} from "@snyk/cloud-config-parser";
import { readFileSync } from "fs";

console.log(
  issuesToLineNumbers(
    readFileSync(process.argv[2]).toString(),
    CloudConfigFileTypes.YAML,
    process.argv[3].split(".")
  )
);
