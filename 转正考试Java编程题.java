
class FilePath {
    public static void main(String[] args) {
        File file = new File("D:/资料");
        Map<String, String> map = new HashMap<>();
        getTxtPath(file, map);
        for (Map.Entry<String, String> entry : map.entrySet()) {
            System.out.println(entry.getKey() + ": " + entry.getValue());
        }
    }

    public static Map<String, String> getTxtPath(File file, Map<String, String> map) {
        File[] listFiles = file.listFiles();
        for (File f : listFiles) {
            if (f.isDirectory()) {
                getTxtPath(f, map);
            } else if (f.getName().endsWith(".txt")) {
                map.put(f.getName(), f.getAbsolutePath());
            }
        }
        return map;
    }
}

class SecondMax {
    public static void main(String[] args) {
        int[] nums = { 1, 2, 4, 3, 6, 4, 7, 8, -6, -2, 6, 2, -65, };
        System.out.println(find2(nums));
        System.out.println(findSecMax(nums));
    }

    public static int find2(int[] nums) {
        Arrays.sort(nums);
        System.out.println(nums);
        return nums[nums.length - 2];
    }

    public static int findSecMax(int[] nums) {
        int max = nums[0];
        int sec = Integer.MIN_VALUE;
        for (int i = 0; i < nums.length; i++) {
            if (nums[i] > max) {
                sec = max;
                max = nums[i];
            } else if (nums[i] > sec) {
                sec = nums[i];
            }
        }
        return sec;
    }
}
