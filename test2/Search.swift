import Foundation

struct Posting {
    var doc: Int
    var boost: Int
    
    func times(amount: Int) -> Posting {
        return Posting(doc: doc, boost: boost * amount)
    }

    func plus(amount: Int) -> Posting {
        return Posting(doc: doc, boost: boost + amount)
    }
}

struct Token: Hashable {
    var text: String
    var offset: Int
    var boost: Int
}

struct Result {
    var text: String
    var score: Int
}

extension Token: Hashable {
    var hashValue: Int {
        return text.hashValue + offset + boost * 1024
    }
}

func ==(lhs: Token, rhs: Token) -> Bool {
    return lhs.text == rhs.text && lhs.offset == rhs.offset && lhs.boost == rhs.boost
}

class Search {
    
    let BOOST_EXACT = 10
    let BOOST_PREFIX = 3
    let BOOST_SHINGLE = 1
    let BOOST_SOUNDEX = 5
    let BOOST_SYNONYM = 5

    // Smallest number of chars you're willing to autocomplete on
    let MIN_PREFIX = 1
    
    // Largest number of chars you're willing to autocomplete on
    let MAX_PREFIX = 6
    
    // N-Gram size for spelling correction
    let SHINGLE_SIZE = 3
    
    // Search index
    var index: [String: [Posting]] = [:]
    var synonyms: [String: [String]] = [:]
    var corpus: [String] = []
    
    // For soundex
    var codes = [
        "a": "0", "e": "0", "i": "0", "o": "0", "u": "0",
        "b": "1", "f": "1", "p": "1", "v": "1",
        "c": "2", "g": "2", "j": "2", "k": "2", "q": "2", "s": "2", "x": "2", "z": "2",
        "d": "3", "t": "3",
        "l": "4",
        "m": "5", "n": "5",
        "r": "6"
    ]
    
    func soundex(s: String) -> String {
        var tmp = Array(s.lowercaseString)
        var f = String(tmp[0])
        var a = Array(tmp[1..<tmp.count])
        
        var i = 0
        var suffix: [String] = a
            .map { self.codes[String($0)] ?? "" }
            .filter({
                var out = false
                if i == 0 {
                    out = (self.codes[f] ?? "") != (self.codes[$0] ?? "")
                } else {
                    out = $0 != String(a[i-1])
                }
                i += 1
                return out
            })
        
        var padded = (String(f) + "".join(suffix) + "000")
        
        return padded.substringToIndex(advance(padded.startIndex, 4)).uppercaseString
    };
    
    func expandTerm(term: String, querying: Bool, offset: Int) -> [Token] {
        var tokens: [Token] = [Token(text: term, offset: offset, boost: BOOST_EXACT)]
        
        tokens.append(Token(text: soundex(term), offset: offset, boost: BOOST_SOUNDEX))
        
        if !querying {
            let max = MAX_PREFIX < count(term) ? MAX_PREFIX : count(term)
            for i in MIN_PREFIX...max {
                tokens.append(Token(text: term.substringToIndex(advance(term.startIndex, i)), offset: offset, boost: BOOST_PREFIX))
            }
        }
        
        let size = (count(term) - SHINGLE_SIZE)
        if size > 0 {
            for i in 0..<size {
                tokens.append(Token(text: term.substringWithRange(advance(term.startIndex, i)..<advance(term.startIndex, i+SHINGLE_SIZE)), offset: offset, boost: BOOST_PREFIX))
            }
        }
        
        if querying {
            if var synonyms = self.synonyms[term] {
                for synonym in synonyms {
                    tokens.append(Token(text: synonym, offset: offset, boost: BOOST_SYNONYM))
                }
            }
        }
        
        return tokens
    }
    
    func tokenize(doc: String, querying: Bool) -> [Token] {
        var terms = split(doc, isSeparator: { $0 == " " })
        var offset = 0
        return terms.reduce([Token](), combine: {(list: [Token], term: String) -> [Token] in
            let out = list + self.expandTerm(term.lowercaseString, querying: querying, offset: offset)
            offset += 1
            return out
        })
    }
    
    func flatten<T>(nested: [[T]]) -> [T] {
        var out: [T] = []
        for inner in nested {
            for value in inner {
                out.append(value)
            }
        }
        return out
    }
    
    func uniq<T: Hashable>(input: [T]) -> [T] {
        var seen = Set<T>()
        var out: [T] = []
        for value in input {
            if !seen.contains(value) {
                out.append(value)
                seen.insert(value)
            }
        }
        return out
    }
    
    func search(query: String, results: Int) -> [Result] {
        let start = NSDate()
        var tokens = tokenize(query, querying: true)
        if tokens.count == 0 {
            return []
        }
        
        let count = tokens.last!.offset + 1
        
        var matches: [[Int: Posting]] = []
        for i in 0..<count {
            matches.append([:])
        }
        for token in tokens {
            if var list = self.index[token.text] {
                var postings = matches[token.offset]
                for item in list {
                    var newer = item.times(token.boost)
                    if var existing = postings[item.doc] {
                        postings[item.doc] = newer.plus(existing.boost)
                    } else {
                        postings[item.doc] = newer
                    }
                }
                matches[token.offset] = postings
            }
        }
        
        var first = matches.removeAtIndex(0)
        var matchingAll = matches.reduce(first, combine: { (existing: [Int: Posting], next: [Int: Posting]) -> [Int: Posting] in
            var out: [Int: Posting] = [:]
            for item in existing {
                if var posting = next[item.0] {
                    out[item.0] = posting.plus(item.1.boost)
                }
            }
            return out
        })
        
        var sorted = matchingAll.values.array
        sorted.sort({(a:Posting, b:Posting) -> Bool in
            return a.boost > b.boost
        })
        
        var resultCount = matchingAll.count > results ? results : matchingAll.count
        var out: [Result] = []

        for i in 0..<resultCount {
            out.append(Result(text: self.corpus[sorted[i].doc], score: sorted[i].boost))
        }
        
        Swift.println("Searched "+query+" in " + String(format: "%f", -start.timeIntervalSinceNow))
        return out
    }
    
    init(corpus: [String], synonyms: [[String]]){
        self.corpus = corpus
        
        // build the synonym bi-mapping
        for pair in synonyms {
            var a = pair[0].lowercaseString
            var b = pair[1].lowercaseString
            if var list = self.synonyms[a] {
                list.append(b)
            } else {
                self.synonyms[a] = [b]
            }
            if var list = self.synonyms[b] {
                list.append(a)
            } else {
                self.synonyms[b] = [a]
            }
        }
        
        // build the search index
        var docId = 0
        for doc in corpus {
            let tokens: [Token] = self.tokenize(doc, querying: false)
            for token in tokens {
                let posting = Posting(doc: docId, boost: token.boost)
                if var list = self.index[token.text] {
                    list.append(posting)
                    self.index[token.text] = list
                } else {
                    self.index[token.text] = [posting]
                }
            }
            docId += 1
        }
    }
}