module Blakley where

import Data.List
import System.Random
import System.IO
import Control.Monad
import Control.Monad.Fix
import Data.Bits
import Math.NumberTheory.Primes.Testing

takeN :: Integer -> [a] -> [a]
takeN n l = take (fromIntegral n) l

dropN :: Integer -> [a] -> [a]
dropN n l = drop (fromIntegral n) l

-- given k and p, return list of k-1 numbers from finite field p
randomList :: Integer -> Integer -> IO [Integer]
randomList k p = do 
    list <- genB 0 (p-1)
    return $ takeN (k-1) list
 where 
	genB :: Random a => a -> a -> IO [a]
	genB a b = fmap (randomRs (a,b)) newStdGen

-- given set A, return set of all subsets of A having length = k
getSubs :: Integer -> [a] -> [[a]]
getSubs k = filterSubsets k . getSubsets'
 where
  getSubsets' [] = [[]]
  getSubsets' (x:xs) = s ++ map (x:) s where s = getSubsets' xs

  filterSubsets :: Integer -> [[a]]-> [[a]]
  filterSubsets k [] = []
  filterSubsets k (x:xs)= if (fromIntegral (length x) == k) then (x:filterSubsets k xs) else filterSubsets k xs

-- given number n and list, return list of sublist of length n 	
sublist :: Integer -> [a] -> [[a]]
sublist n ls
    | n <= 0 || null ls = []
    | otherwise = takeN n ls:sublist n (dropN n ls) 

-- given m, p, [bi] and [ai]k, return di
getDi :: Integer -> Integer -> [Integer] -> [Integer] -> Integer 
getDi m p blist alist = rem ((head alist * m) + 
  foldl (+) 0 (zipWith (*) (tail alist) blist)) p

-- given k, m, p, [bi] and [ai]n, return [di]
getDiList :: Integer -> Integer -> Integer ->
 [Integer] -> [Integer] -> [Integer]
getDiList k m p blist alist = map (getDi m p blist) (sublist k alist)

-- given k, [ai]n, [d1] and return system of n plane equations (a1i..aki,di)
getEquations :: Integer -> [Integer] -> [Integer] -> [[Integer]]
getEquations k alist dlist = map (change) temp
  where
	temp = zipWith (:) dlist (sublist k alist)
	change (x:xs) = xs ++ [x]  
	
-- use this for Cramer's method (to solve system of linear equations)
determinant :: [[Integer]] -> Integer -> Integer
determinant [[x]] p = x
determinant mat p = sumrem [multrem ((-1)^i*x)
  (determinant (returnWithout i mat) p) p | 
  (i, x) <- zip [0..] (head mat)] p
  where
	multrem a b p = (a * b) `rem` p 
	
	sumrem [] p = 0
	sumrem [x] p = rem x p
	sumrem (x:y:xs) p = (rem (x+y) p) + sumrem xs p
	
	returnWithout i mat = removeCols i (tail mat)
	
	removeCols _ [] = []
	removeCols i (r:rs) = (left ++ (tail right)) 
	 : removeCols i rs
		where (left, right) = splitAt i r
 
-- extended GCD algorithm to find secret after apply a Cramer's method for finite field p
eGCD :: Integer -> Integer -> (Integer, Integer, Integer)
eGCD 0 b = (b, 0, 1)
eGCD a b = let (g, s, t) = eGCD (b `mod` a) a
           in (g, t - (b `div` a) * s, s)
		   
rndPrime :: Integer -> IO Integer
rndPrime bits = 
	fix $ \again -> do
	x <- fmap (.|. 1) $ randomRIO (2*bits, 3*bits)
	if isPrime x then return x else again

-- m is secret, (k, n) threshold scheme, k' are allow parts, if k = k' everything is OK
blakley m k n k' = do 
--encrypt section
	maxbound <- return $ 1 + max m n
	p <- rndPrime $ maxbound
	listB <- randomList k p 
	listA <- randomList (k*n+1) p
	listD <- return $ getDiList k m p listB listA
	equations <- return $ getEquations k listA listD
	
	putStr $ "secret = "
	print $ m
	
	{-putStr $ "p = "
	print $ p
	
	putStr $ "ai [k * n]= "
	print $ listA
	
  	putStr $ "[b2..bk] = "	
	print $ listB
	
	putStr $ "[d1..dn] = "
	print $ listD-}
	
	putStr $ "shares = "
	print $ equations
	x <- decrypt p k' k equations
	return $ x

-- decrypt section: p > M (it's a mod for field arithmetic); shares for participants; k is a minimal allowable number of participants; k' is a test number
decrypt p k' k shares = do
	sharesSubset <- return $ (getSubs k' shares)
	index <- randomRIO (0, length sharesSubset - 1)
	shares' <- return $ sharesSubset !! index
	equationsK <- return $ takeN k' $ map (takeN (k'+1)) shares'
	
	mat1 <- return $ takeN k $ map (init) equationsK
	mat2 <- return $ zipWith (:) (map (last) equationsK) $ takeN k (map (tail . init) equationsK) 
	
	det1 <- return $ determinant mat1 p
	det2 <- return $ determinant mat2 p
	
	x <- return $ mod det2 p
	
	(d,a,b) <- return $ eGCD det1 p
	reduceSecret <- return $ mod (a*x) p  
	secret <- return $ if reduceSecret > (p `div` 2) then (p - reduceSecret) else reduceSecret
	
	{-putStr $ "shares' = "
	print $ shares'
	
	putStr $ "k shares = "
	print $ equationsK
	
	putStr $ "mat1 = "
	print $ mat1
	
	putStr $ "mat2 = "
	print $ mat2
	
	putStr $ "det mat1 = "
	print $ det1
	
	putStr $ "det mat2 = "
	print $ det2-}
	
	putStr $ "secret = "
	print $ secret
