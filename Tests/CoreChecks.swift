import Foundation
@main struct CoreChecks {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message:String) { precondition(condition(),message); count += 1 }
        check(DecisionPolicy.route(.binary,DecisionPolicy.fixture(.binary)).title == "Pretzel","binary fixture")
        check(DecisionPolicy.route(.choice,DecisionPolicy.fixture(.choice)).title == "Pretzel","choice fixture")
        check(DecisionPolicy.route(.packing,DecisionPolicy.fixture(.packing)).title == "Check the order","packing negative")
        for mode in BakeryMode.allCases {
            check(DecisionPolicy.route(mode,.init(answers:[])).title == "Check manually","empty answers")
            var r = DecisionPolicy.fixture(mode); r.answers[0].type = "refusal"
            check(DecisionPolicy.route(mode,r).title == "Check manually","refusal")
            r = DecisionPolicy.fixture(mode); r.answers[0].probability = .nan
            check(DecisionPolicy.route(mode,r).title == "Check manually","NaN")
            r = DecisionPolicy.fixture(mode); r.answers[0].probability = 0.79
            check(DecisionPolicy.route(mode,r).title == "Check manually","unclear")
        }
        var r = DecisionPolicy.fixture(.binary); r.answers[1].probability = 0.2
        check(DecisionPolicy.route(.binary,r).title == "Check manually","multiple")
        r = DecisionPolicy.fixture(.binary); r.answers[2].probability = 0.5
        check(DecisionPolicy.route(.binary,r).title == "Check manually","middle")
        r = DecisionPolicy.fixture(.choice); r.answers[2].confidence = 0.59
        check(DecisionPolicy.route(.choice,r).title == "Check manually","confidence")
        r = DecisionPolicy.fixture(.choice); r.answers[2].probabilities = []
        check(DecisionPolicy.route(.choice,r).title == "Check manually","malformed distribution")
        r = DecisionPolicy.fixture(.binary); r.answers[1].name = "clear"
        check(DecisionPolicy.route(.binary,r).title == "Check manually","duplicate name")
        check(DecisionPolicy.route(.binary,DecisionPolicy.fixture(.binary)).outcome == .positive,"positive signal")
        check(DecisionPolicy.route(.packing,DecisionPolicy.fixture(.packing)).outcome == .negative,"negative packing signal")
        r = DecisionPolicy.fixture(.binary); r.answers[2].probability = 0.1
        check(DecisionPolicy.route(.binary,r).outcome == .negative,"negative binary signal")
        r.answers[2].probability = 0.5
        check(DecisionPolicy.route(.binary,r).outcome == .review,"uncertainty must not show red or green")
        r.answers[0].probability = 0.1
        check(DecisionPolicy.route(.binary,r).outcome == .review,"unclear view must not show red")
        for category in ["doughnut", "cookie", "bread_roll"] {
            r = DecisionPolicy.fixture(.choice); r.answers[2].choice = category
            r.answers[2].probabilities = DecisionPolicy.categories.map { .init(value:$0,probability:$0 == category ? 0.95 : 0.01) }
            check(DecisionPolicy.route(.choice,r).title == DecisionPolicy.labels[category],"expanded category")
            r.answers[2].probabilities?.removeLast()
            check(DecisionPolicy.route(.choice,r).outcome == .review,"incomplete six-category distribution")
        }
        check((DecisionPolicy.questions(.choice)[2]["choices"] as? [[String:String]])?.count == 6,"six choices sent to API")
        for category in DecisionPolicy.crowdCategories {
            r = DecisionPolicy.fixture(.crowd); r.answers[1].choice = category
            r.answers[1].probabilities = DecisionPolicy.crowdCategories.map { .init(value:$0,probability:$0 == category ? 0.97 : 0.01) }
            check(DecisionPolicy.route(.crowd,r).outcome == (category == "unclear" ? .review : .positive),"gesture classification")
            r.answers[1].probabilities?.removeLast()
            check(DecisionPolicy.route(.crowd,r).outcome == .review,"incomplete gesture distribution")
        }
        r = DecisionPolicy.fixture(.crowd); r.answers[1].confidence = 0.5
        check(DecisionPolicy.route(.crowd,r).outcome == .review,"uncertain gestures")
        let data = try DecisionPolicy.request(.choice,jpeg:Data([1,2,3]))
        let json = try JSONSerialization.jsonObject(with:data) as! [String:Any]
        check(json["model"] as? String == "gpt-6-luna","model")
        check((json["questions"] as? [[String:Any]])?.count == 3,"question count")
        print("Passed \(count) native policy checks.")
    }
}
