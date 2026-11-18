import from "clsx" { clsx }
import from "tailwind-merge" { twMerge }

def cn(*inputs: any) -> str {
    return twMerge(clsx(inputs));
}
